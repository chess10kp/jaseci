import from z {
    def compress2(dst: bytes, dlen: bytes, src: bytes, slen: u64, lvl: i32) -> i32;
}
import from z {
    def uncompress(dst: bytes, dlen: bytes, src: bytes, slen: u64) -> i32;
}
import from z {
    def uncompress2(dst: bytes, dlen: bytes, src: bytes, slen: bytes) -> i32;
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

glob _Z_OK: int = 0,
     _Z_STREAM_END: int = 1,
     _Z_MEM_ERROR: int = -4,
     _Z_BUF_ERROR: int = -5;


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


def:pub z_uncompress(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int
) -> int {
    return _signed32(uncompress(dest, dest_len, source, u64(source_len)));
}


def:pub z_uncompress2(
    dest: bytes, dest_len: bytes, source: bytes, source_len: bytes
) -> int {
    return _signed32(uncompress2(dest, dest_len, source, source_len));
}


def:pub z_crc32(crc: int, buf: bytes, n: int) -> int {
    return int(crc32_z(u64(crc), buf, u64(n)));
}


def:pub z_adler32(adler: int, buf: bytes, n: int) -> int {
    return int(adler32_z(u64(adler), buf, u64(n)));
}


def:pub z_strm_bytes -> bytes {
    return b"\x00" * 112;
}


def:pub z_payload_addr(buf: bytes) -> int {
    return memchr(buf, i32(buf[0]), u64(1));
}


def:pub z_inflate_init(
    strm: bytes, src: bytes, src_off: int, src_len: int, window_bits: int
) -> int {
    sa: int = z_payload_addr(strm);
    in_ptr: int = 0;
    if src_len > 0 {
        in_ptr = z_payload_addr(src) + src_off;
    }
    __mem_store_i64(sa + _ZS_NEXT_IN, in_ptr);
    __mem_store_i32(sa + _ZS_AVAIL_IN, i32(src_len));
    return _signed32(inflateInit2_(strm, i32(window_bits), zlibVersion(), i32(112)));
}


def:pub z_inflate_set_out(strm: bytes, out_addr: int, room: int) {
    sa: int = z_payload_addr(strm);
    __mem_store_i64(sa + _ZS_NEXT_OUT, out_addr);
    __mem_store_i32(sa + _ZS_AVAIL_OUT, i32(room));
}


def:pub z_alloc(n: int) -> int {
    return malloc(u64(n));
}


def:pub z_realloc(p: int, n: int) -> int {
    return realloc(p, u64(n));
}


def:pub z_free(p: int) {
    free(p);
}


def:pub z_inflate(strm: bytes) -> int {
    return _signed32(inflate(strm, i32(0)));
}


def:pub z_inflate_total_out(strm: bytes) -> int {
    return __mem_load_i64(z_payload_addr(strm) + _ZS_TOTAL_OUT);
}


def:pub z_inflate_total_in(strm: bytes) -> int {
    return __mem_load_i64(z_payload_addr(strm) + _ZS_TOTAL_IN);
}


def:pub z_inflate_end(strm: bytes) -> int {
    return _signed32(inflateEnd(strm));
}


def:pub z_copy(dst: bytes, src_addr: int, n: int) {
    memcpy(dst, src_addr, u64(n));
}


obj:pub ZInflateResult {
    has status: int,
        data: bytes;
}


def:pub z_inflate_all(strm: bytes, cap: int, ceiling: int) -> ZInflateResult {
    buf: int = z_alloc(cap);
    if buf == 0 {
        return ZInflateResult(status=_Z_MEM_ERROR, data=b"");
    }
    total: int = 0;
    status: int = _Z_OK;
    while True {
        if total == cap {
            if cap >= ceiling {
                status = _Z_BUF_ERROR;
                break;
            }
            newcap: int = cap * 2;
            if newcap > ceiling {
                newcap = ceiling;
            }
            nbuf: int = z_realloc(buf, newcap);
            if nbuf == 0 {
                status = _Z_MEM_ERROR;
                break;
            }
            buf = nbuf;
            cap = newcap;
        }
        z_inflate_set_out(strm, buf + total, cap - total);
        status = z_inflate(strm);
        total = z_inflate_total_out(strm);
        if status != _Z_OK {
            if status == _Z_BUF_ERROR and total == cap {
                continue;
            }
            break;
        }
    }
    data = b"";
    if status == _Z_STREAM_END {
        out = b"\x00" * total;
        z_copy(out, buf, total);
        data = out;
    }
    z_free(buf);
    return ZInflateResult(status=status, data=data);
}
