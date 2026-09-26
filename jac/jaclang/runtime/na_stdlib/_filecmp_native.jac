import from c { def stat(path: str, buf: int) -> i32;  }
import from c { def malloc(size: int) -> int;  }

glob _FC_STBUF: int = malloc(512);

def _sig_mix -> int {
    mode: int = __mem_load_i32(_FC_STBUF + 24) & 61440;
    size: int = __mem_load_i64(_FC_STBUF + 48);
    mtsec: int = __mem_load_i64(_FC_STBUF + 88);
    mtnsec: int = __mem_load_i64(_FC_STBUF + 96);
    h: int = mode;
    h = (h * 131 + size) % 9223372036854775807;
    h = (h * 131 + mtsec) % 9223372036854775807;
    h = (h * 131 + mtnsec) % 9223372036854775807;
    return h;
}

def:pub fc_probe(path: str) -> int {
    if stat(path, _FC_STBUF) != 0 {
        return -1;
    }
    mode: int = __mem_load_i32(_FC_STBUF + 24);
    return _sig_mix() * 2 + (1 if (mode & 61440) == 32768 else 0);
}

def:pub fc_size(path: str) -> int {
    if stat(path, _FC_STBUF) != 0 {
        return -1;
    }
    return __mem_load_i64(_FC_STBUF + 48);
}

def:pub fc_kind(path: str) -> int {
    if stat(path, _FC_STBUF) != 0 {
        return -1;
    }
    mode: int = __mem_load_i32(_FC_STBUF + 24) & 61440;
    if mode == 32768 {
        return 1;
    }
    if mode == 16384 {
        return 2;
    }
    return 0;
}
