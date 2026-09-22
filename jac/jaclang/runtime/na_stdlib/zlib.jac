import from _zlib_native {
    ZInflateResult,
    z_compress2,
    z_compress_bound,
    z_crc32,
    z_adler32,
    z_strm_bytes,
    z_inflate_init,
    z_inflate_all,
    z_inflate_end
}

glob _ZL_OK: int = 0,
     _ZL_STREAM_END: int = 1,
     _ZL_MEM_ERROR: int = -4;


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
    if rc != _ZL_OK {
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
    if rc != _ZL_OK {
        if rc == _ZL_MEM_ERROR {
            raise MemoryError("zlib.decompress: allocation failed");
        }
        raise ValueError(
            "zlib.decompress: inflate init failed (libz error code " + str(rc) + ")"
        );
    }
    cap: int = source_len * 4;
    if cap < 8192 {
        cap = 8192;
    }
    ceiling: int = (source_len * 1032) + 67108864;
    res: ZInflateResult = z_inflate_all(strm, cap, ceiling);
    z_inflate_end(strm);
    if res.status == _ZL_STREAM_END {
        return res.data;
    }
    if res.status == _ZL_MEM_ERROR {
        raise MemoryError("zlib.decompress: allocation failed");
    }
    raise ValueError(
        "zlib.decompress: invalid or truncated stream (libz error code "
            + str(res.status)
            + ")"
    );
}
