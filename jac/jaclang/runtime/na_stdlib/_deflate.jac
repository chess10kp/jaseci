import from _zlib_native { z_uncompress2, z_adler32 }

glob:priv _Z_OK: int = 0,
     _Z_DATA_ERROR: int = -3,
     _Z_BUF_ERROR: int = -5,
     _ZLIB_HEADER: bytes = b"\x78\x9c",
     _ADLER_PLACEHOLDER: bytes = b"\x00\x00\x00\x00";

def inflate_once(body: bytes, trailer: bytes, cap: int) -> (int, bytes, int) {
    framed = _ZLIB_HEADER + body + trailer;
    dest = b"\x00" * cap;
    dest_len = cap.to_bytes(8, "little");
    src_len = len(framed).to_bytes(8, "little");
    rc = z_uncompress2(dest, dest_len, framed, src_len);
    return (
        rc,
        dest[0:int.from_bytes(dest_len, "little")],
        int.from_bytes(src_len, "little")
    );
}

def inflate_exact(data: bytes, size: int) -> (bytes | None) {
    (rc, out, consumed) = inflate_once(data, _ADLER_PLACEHOLDER, size + 1);
    framed_len = len(data) + 6;
    if (rc != _Z_OK and rc != _Z_DATA_ERROR)
        or len(out) != size
        or consumed != framed_len {
        return None;
    }
    trailer = z_adler32(1, out, size).to_bytes(4, "big");
    (rc, check, consumed) = inflate_once(data, trailer, size + 1);
    if rc != _Z_OK or len(check) != size or consumed != framed_len {
        return None;
    }
    return out;
}

def inflate_growable(
    data: bytes, cap: int, ceiling: int
) -> (tuple[bytes, int] | None) {
    while True {
        (rc, out, consumed) = inflate_once(data, _ADLER_PLACEHOLDER, cap);
        if rc == _Z_OK or rc == _Z_DATA_ERROR {
            return (out, consumed);
        }
        if rc == _Z_BUF_ERROR and cap < ceiling {
            cap = cap * 2;
            if cap > ceiling {
                cap = ceiling;
            }
            continue;
        }
        return None;
    }
}
