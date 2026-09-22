import from z {
    def compress2(dst: bytes, dlen: bytes, src: bytes, slen: u64, lvl: i32) -> i32;
}
import from z { def compressBound(slen: u64) -> u64;  }
import from z { def crc32_z(crc: u64, buf: bytes, n: u64) -> u64;  }
import from z { def adler32_z(adler: u64, buf: bytes, n: u64) -> u64;  }
import from z {
    def inflateInit2_(
        strm: bytes, windowBits: i32, version: int, stream_size: i32
    ) -> i32;
}
import from z { def inflate(strm: bytes, flush: i32) -> i32;  }
import from z { def inflateEnd(strm: bytes) -> i32;  }
import from z { def zlibVersion -> int;  }
import from c { def memchr(s: bytes, c: i32, n: u64) -> int;  }
import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }
import from c { def malloc(n: u64) -> int;  }
import from c { def realloc(p: int, n: u64) -> int;  }
import from c { def free(p: int) -> None;  }

glob _ZS_NEXT_IN: int = 0,
     _ZS_AVAIL_IN: int = 8,
     _ZS_TOTAL_IN: int = 16,
     _ZS_NEXT_OUT: int = 24,
     _ZS_AVAIL_OUT: int = 32,
     _ZS_TOTAL_OUT: int = 40;

glob _Z_STREAM_SIZE: int = 112,
     _UINT32_MAX: int = 4294967295;

glob:pub Z_OK: int = 0,
     Z_STREAM_END: int = 1,
     Z_MEM_ERROR: int = -4,
     Z_BUF_ERROR: int = -5;


def _signed32(status: int) -> int {
    if status >= 2147483648 {
        return status - 4294967296;
    }
    return status;
}


def:pub z_compress_bound(source_len: int) -> int {
    return int(compressBound(u64(source_len)));
}


def:pub z_compress2(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int, level: int
) -> int {
    return _signed32(compress2(dest, dest_len, source, u64(source_len), i32(level)));
}


def:pub z_crc32(crc: int, buf: bytes, n: int) -> int {
    return int(crc32_z(u64(crc), buf, u64(n)));
}


def:pub z_adler32(adler: int, buf: bytes, n: int) -> int {
    return int(adler32_z(u64(adler), buf, u64(n)));
}


def:pub z_inflate_bound(src_len: int, slack: int = 1024) -> int {
    return src_len * 1032 + slack;
}


def _payload_addr(buf: bytes) -> int {
    if len(buf) == 0 {
        return 0;
    }
    return memchr(buf, i32(buf[0]), u64(1));
}


def _store_u32(addr: int, value: int) {
    if value > _UINT32_MAX {
        value = _UINT32_MAX;
    }
    __mem_store_i32(addr, i32.wrap(value));
}


def _inflate_init(
    strm: bytes, src: bytes, src_off: int, src_len: int, window_bits: int
) -> int {
    sa: int = _payload_addr(strm);
    in_ptr: int = 0;
    if src_len > 0 {
        in_ptr = _payload_addr(src) + src_off;
    }
    __mem_store_i64(sa + _ZS_NEXT_IN, in_ptr);
    _store_u32(sa + _ZS_AVAIL_IN, src_len);
    return _signed32(
        inflateInit2_(strm, i32(window_bits), zlibVersion(), i32(_Z_STREAM_SIZE))
    );
}


def _inflate_set_out(strm: bytes, out_addr: int, room: int) {
    sa: int = _payload_addr(strm);
    __mem_store_i64(sa + _ZS_NEXT_OUT, out_addr);
    _store_u32(sa + _ZS_AVAIL_OUT, room);
}


def _inflate_refeed_in(strm: bytes, remaining: int) {
    _store_u32(_payload_addr(strm) + _ZS_AVAIL_IN, remaining);
}


def _inflate(strm: bytes) -> int {
    return _signed32(inflate(strm, i32(0)));
}


def _inflate_total_in(strm: bytes) -> int {
    return __mem_load_i64(_payload_addr(strm) + _ZS_TOTAL_IN);
}


def _inflate_total_out(strm: bytes) -> int {
    return __mem_load_i64(_payload_addr(strm) + _ZS_TOTAL_OUT);
}


def _inflate_end(strm: bytes) {
    inflateEnd(strm);
}


obj:pub ZInflateResult {
    has status: int,
        consumed: int,
        data: bytes,
        init_ok: bool = True;
}


def:pub z_inflate_all(
    src: bytes, src_off: int, src_len: int, window_bits: int, cap: int, ceiling: int
) -> ZInflateResult {
    strm: bytes = b"\x00" * _Z_STREAM_SIZE;
    rc: int = _inflate_init(strm, src, src_off, src_len, window_bits);
    if rc != Z_OK {
        return ZInflateResult(status=rc, consumed=0, data=b"", init_ok=False);
    }
    if cap < 1 {
        cap = 1;
    }
    buf: int = malloc(u64(cap));
    status: int = Z_OK;
    if buf == 0 {
        status = Z_MEM_ERROR;
    }
    total: int = 0;
    while status == Z_OK {
        if total == cap {
            if cap >= ceiling {
                status = Z_BUF_ERROR;
                break;
            }
            newcap: int = cap * 2;
            if newcap > ceiling {
                newcap = ceiling;
            }
            nbuf: int = realloc(buf, u64(newcap));
            if nbuf == 0 {
                status = Z_MEM_ERROR;
                break;
            }
            buf = nbuf;
            cap = newcap;
        }
        _inflate_set_out(strm, buf + total, cap - total);
        status = _inflate(strm);
        total = _inflate_total_out(strm);
        if status == Z_BUF_ERROR {
            fed: int = _inflate_total_in(strm);
            if fed < src_len {
                _inflate_refeed_in(strm, src_len - fed);
                status = Z_OK;
            } elif total == cap {
                status = Z_OK;
            }
        }
    }
    data = b"";
    if status == Z_STREAM_END {
        out = b"\x00" * total;
        memcpy(out, buf, u64(total));
        data = out;
    }
    consumed: int = _inflate_total_in(strm);
    free(buf);
    _inflate_end(strm);
    return ZInflateResult(status=status, consumed=consumed, data=data);
}
