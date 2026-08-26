# Product-path facade for zlib.
# Semantics mirror CPython 3.14 ``Modules/zlibmodule.c``: the module-level
# constant surface built by ``zlib_exec`` (the ZLIB_ADD_INT_MACRO block), the
# checksum pair ``crc32``/``adler32``, and the byte-exact ``zlib_error``
# message-formatting logic shared by every call-through.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is a
# thin binding over libz -- compress/decompress and the Compress/Decompress
# incremental state machines own live z_stream handles and stay host-side,
# resolved through the delegation registry exactly like re/hashlib/zlib per
# the ssl.jac precedent. This facade lifts everything zlibmodule.c exports
# that is a pure computation or compile-time value, so guest code (and
# py2jac'd test_zlib snippets) can bind constants, run checksums and pin
# error-text formats without crossing the boundary.
#
# Out of scope by design (needs live z_stream state): compress, decompress,
# compressobj, decompressobj, Compress, Decompress, _ZlibDecompressor.
# ZLIB_VERSION / ZLIB_RUNTIME_VERSION are omitted for the same reason: they
# are properties of the linked zlib build, not of this source.
#
# Checksum note: crc32 deliberately reimplements the table walk instead of
# importing binascii's -- the two modules take different converters
# (Py_buffer rejects ``str``; binascii's ascii_buffer accepts pure-ASCII
# ``str``), so sharing the walk would silently widen zlib's accepted inputs.

glob MAX_WBITS: int = 15,
     DEFLATED: int = 8,
     DEF_MEM_LEVEL: int = 8,
     DEF_BUF_SIZE: int = 16 * 1024;

# ---- compression levels ----

glob Z_NO_COMPRESSION: int = 0,
     Z_BEST_SPEED: int = 1,
     Z_BEST_COMPRESSION: int = 9,
     Z_DEFAULT_COMPRESSION: int = -1;

# ---- compression strategies ----

glob Z_FILTERED: int = 1,
     Z_HUFFMAN_ONLY: int = 2,
     Z_RLE: int = 3,
     Z_FIXED: int = 4,
     Z_DEFAULT_STRATEGY: int = 0;

# ---- allowed flush values ----

glob Z_NO_FLUSH: int = 0,
     Z_PARTIAL_FLUSH: int = 1,
     Z_SYNC_FLUSH: int = 2,
     Z_FULL_FLUSH: int = 3,
     Z_FINISH: int = 4,
     Z_BLOCK: int = 5,
     Z_TREES: int = 6;

# PyModule_AddStringConstant(mod, "__version__", "1.0")
glob __version__: str = "1.0";

# z_stream error codes referenced by the message mapping below.
glob _Z_BUF_ERROR: int = -5,
     _Z_STREAM_ERROR: int = -2,
     _Z_DATA_ERROR: int = -3,
     _Z_VERSION_ERROR: int = -6;


# ---------------------------------------------------------------------------
# Error surface
#

def _error(msg: str) {
    # zlib.error identity follows the facade bridge-table convention:
    # name-matched against Exception at import ("zlib.Error"), the same way
    # csv.Error / binascii.Error cross the boundary verbatim.
    raise Exception(msg);
}


def _type_name(v: any) -> str {
    return type(v).__name__;
}


def zlib_error_message(err: int, msg: str, zmsg: str = "") -> str {
    # Mirror zlib_error(): a version mismatch never trusts zst.msg; a NULL
    # zmsg falls back to the err-code table; %.200s truncates the final
    # detail to 200 characters.
    if err == _Z_VERSION_ERROR {
        zmsg = "library version mismatch";
    }
    if zmsg == "" {
        if err == _Z_BUF_ERROR {
            zmsg = "incomplete or truncated stream";
        } elif err == _Z_STREAM_ERROR {
            zmsg = "inconsistent stream state";
        } elif err == _Z_DATA_ERROR {
            zmsg = "invalid input data";
        }
    }
    if zmsg == "" {
        return "Error " + str(err) + " " + msg;
    }
    if len(zmsg) > 200 {
        zmsg = zmsg[:200];
    }
    return "Error " + str(err) + " " + msg + ": " + zmsg;
}


# ---------------------------------------------------------------------------
# Buffer conversion (Py_buffer semantics: str is rejected)
#

def _byte_view(arg: any) -> any {
    # Duck-typed bytes-like: bytes, bytearray, memoryview all expose len()
    # plus integer indexing into 0..255. ``str`` fails the Py_buffer
    # converter in C ("a bytes-like object is required") even when ASCII.
    if isinstance(arg, str) {
        raise TypeError(
            "a bytes-like object is required, not '" + _type_name(arg) + "'");
    }
    try {
        len(arg);
    } except Exception {
        raise TypeError(
            "a bytes-like object is required, not '" + _type_name(arg) + "'");
    }
    return arg;
}


# ---------------------------------------------------------------------------
# Checksums: adler32 / crc32
#

def adler32(data: any, value: int = 1) -> int {
    # zlib_adler32_impl -> adler32(value, buf, len): s1/s2 split of the
    # unsigned-int seed, modulo 65521 per byte (the C NMAX batching is a
    # perf-only divergence), result masked to 32 bits.
    buf = _byte_view(data);
    s1 = value & 0xFFFF;
    s2 = (value >> 16) & 0xFFFF;
    for k in range(len(buf)) {
        s1 = (s1 + buf[k]) % 65521;
        s2 = (s2 + s1) % 65521;
    }
    return ((s2 << 16) | s1) & 0xFFFFFFFF;
}


# CRC-32 table walk (internal_crc32 / crc_32_tab). Entry i is the CRC of
# byte i starting from ~0; generated per-entry with polynomial 0xEDB88320 --
# identical values to the C table without a 256-literal glob.
def _crctab32(i: int) -> int {
    v = i;
    for _ in range(8) {
        if v & 1 {
            v = (v >> 1) ^ 0xEDB88320;
        } else {
            v >>= 1;
        }
    }
    return v & 0xFFFFFFFF;
}


def crc32(data: any, value: int = 0) -> int {
    # zlib_crc32_impl -> crc32(value, buf, len): unsigned_int(bitwise=True)
    # seed, masked to 32 bits exactly like the C unsigned int arithmetic.
    c = (~value) & 0xFFFFFFFF;
    buf = _byte_view(data);
    for k in range(len(buf)) {
        c = (_crctab32((c ^ buf[k]) & 0xFF) ^ (c >> 8)) & 0xFFFFFFFF;
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
