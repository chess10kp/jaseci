import from _zlib_native {
    z_compress2,
    z_compress_bound,
    z_crc32,
    z_adler32,
    z_strm_bytes,
    z_inflate_init,
    z_inflate_set_out_raw,
    z_inflate,
    z_inflate_total_out,
    z_inflate_end,
    z_copy,
    z_alloc,
    z_realloc,
    z_free
}

glob Z_OK: int = 0,
     Z_BUF_ERROR: int = -5,
     _Z_STREAM_END: int = 1;


def:pub crc32(data: bytes, value: int = 0) -> int {
    return z_crc32(value, data, len(data));
}


def:pub adler32(data: bytes, value: int = 1) -> int {
    return z_adler32(value, data, len(data));
}


def:pub compress(data: bytes, level: int = -1) -> bytes {
    source_len: int = len(data);

    bound: int = z_compress_bound(source_len);
    dest = b"\x00" * bound;
    dest_len = bound.to_bytes(8, "little");
    rc: int = z_compress2(dest, dest_len, data, source_len, level);
    if rc != Z_OK {
        raise ValueError("zlib.compress: libz error code " + str(rc));
    }
    return dest[0:int.from_bytes(dest_len, "little")];
}


def:pub decompress(data: bytes | bytearray) -> bytes {
    source: bytes;
    if isinstance(data, bytearray) {
        source = bytes(data);
    } else {
        source = data;
    }
    source_len: int = len(source);

    strm: bytes = z_strm_bytes();
    rc: int = z_inflate_init(strm, source, 0, source_len, 15);
    if rc != Z_OK {
        raise ValueError(
            "zlib.decompress: inflate init failed (libz error code " + str(rc) + ")"
        );
    }

    cap: int = source_len * 4;
    if cap < 8192 {
        cap = 8192;
    }
    ceiling: int = (source_len * 1032) + 67108864;
    buf: int = z_alloc(cap);
    if buf == 0 {
        z_inflate_end(strm);
        raise MemoryError("zlib.decompress: allocation failed");
    }
    total: int = 0;
    while True {
        if total == cap {
            if cap >= ceiling {
                z_free(buf);
                z_inflate_end(strm);
                raise ValueError(
                    "zlib.decompress: invalid or truncated stream (libz error code -5)"
                );
            }
            newcap: int = cap * 2;
            if newcap > ceiling {
                newcap = ceiling;
            }
            nbuf: int = z_realloc(buf, newcap);
            if nbuf == 0 {
                z_free(buf);
                z_inflate_end(strm);
                raise MemoryError("zlib.decompress: allocation failed");
            }
            buf = nbuf;
            cap = newcap;
        }
        z_inflate_set_out_raw(strm, buf + total, cap - total);
        status: int = z_inflate(strm);
        total = z_inflate_total_out(strm);
        if status == _Z_STREAM_END {
            break;
        }
        if status != Z_OK {
            if status == Z_BUF_ERROR and total == cap {
                continue;
            }
            z_free(buf);
            z_inflate_end(strm);
            raise ValueError(
                "zlib.decompress: invalid or truncated stream (libz error code "
                    + str(status)
                    + ")"
            );
        }
    }
    z_inflate_end(strm);
    out = b"\x00" * total;
    z_copy(out, buf, total);
    z_free(buf);
    return out;
}
