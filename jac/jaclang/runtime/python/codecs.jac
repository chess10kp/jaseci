# Product-path facade for _codecs (codec registry + builtin codec primitives).
# Semantics mirror CPython 3.14 ``Modules/_codecsmodule.c``: the registry entry
# points (register/unregister/lookup/encode/decode), the fixed-function text
# codec primitives returning ``(result, consumed)`` codec tuples, and the error
# handler registry (register_error/_unregister_error/lookup_error).
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is almost
# entirely thin wrappers over Unicode-object internals (PyUnicode_DecodeUTF8 &
# friends) plus the interpreter-wide codec registries. This facade delegates
# those floors to the host ``_codecs`` extension -- exactly like C extensions
# stay host-proxied on the import path -- and implements natively only what the
# module FILE itself owns inline: ``escape_encode`` (the byte-level
# backslash-escaping loop), ``readbuffer_encode`` (verbatim copy) and
# ``escape_decode`` (the PyBytes_DecodeEscape state machine it drives).
#
# Divergences:
# - Registry state is the HOST interpreter's registry. Guest search functions /
#   error handlers cross as host-callable proxies; anything the host cannot
#   call surfaces at call time, not registration time.
# - The DeprecationWarning PyBytes_DecodeEscape emits for invalid octal escapes
#   and unknown escape characters is not re-emitted (guest warning plumbing);
#   decoded output is byte-identical, including octal wraps past 0o377.
# - MS_WINDOWS-only entries (mbcs/oem/code_page encode+decode) are absent,
#   matching the non-Windows build of the reference source, same policy as the
#   removed hqx family in the binascii lift.

import _codecs as host_codecs;


# ---------------------------------------------------------------------------
# Shared helpers
#

def _codec_tuple(value: any, consumed: int) -> tuple[any, int] {
    # codec_tuple(): Py_BuildValue("Nn", decoded, len).
    return (value, consumed);
}

# py_buffer(accept={str, buffer}) normalization: ``str`` rides the UTF-8
# buffer view (getargs s* semantics), everything else needs the buffer
# protocol -- duck-typed here as len() plus integer indexing into 0..255.
def _buffer_bytes(data: any) -> list[int] {
    if isinstance(data, bytes) or isinstance(data, bytearray) {
        out: list[int] = [];
        for k in range(len(data)) {
            out.append((data as any)[k] as int);
        }
        return out;
    }
    if isinstance(data, str) {
        bb = (data as str).encode();
        out2: list[int] = [];
        for v in bb {
            out2.append(v);
        }
        return out2;
    }
    try {
        n = len(data);
    } except Exception {
        raise TypeError(
            "argument should be bytes-like buffer or ASCII string, not '"
            + type(data).__name__ + "'");
    }
    out3: list[int] = [];
    for k in range(n) {
        item = (data as any)[k];
        if item < 0 or item > 255 {
            raise TypeError("bytes-like object required");
        }
        out3.append(item as int);
    }
    return out3;
}


# ---------------------------------------------------------------------------
# Registry (delegate)
#

def register(search_function: any) {
    # _codecs_register_impl: PyCodec_Register.
    host_codecs.register(search_function);
}

def unregister(search_function: any) {
    # _codecs_unregister_impl: PyCodec_Unregister; missing entry is a no-op.
    host_codecs.unregister(search_function);
}

def lookup(encoding: str) -> any {
    # _codecs_lookup_impl: _PyCodec_Lookup.
    return host_codecs.lookup(encoding);
}

def encode(obj_: any, encoding: str = "utf-8", errors: str = "strict") -> any {
    # _codecs_encode_impl: PyCodec_Encode via the registry.
    return host_codecs.encode(obj_, encoding, errors);
}

def decode(obj_: any, encoding: str = "utf-8", errors: str = "strict") -> any {
    # _codecs_decode_impl: PyCodec_Decode via the registry.
    return host_codecs.decode(obj_, encoding, errors);
}


# ---------------------------------------------------------------------------
# String codecs implemented natively in this file
#

def escape_decode(data: any, errors: any = None) -> tuple[any, int] {
    # _codecs_escape_decode_impl driving PyBytes_DecodeEscape
    # (_PyBytes_DecodeEscape2): standard single-char escapes, \<newline>
    # continuation, \ooo octal (exactly three consumed digits max, wraps past
    # 0o377), \xhh with strict/replace/ignore discipline, unknown escapes kept
    # verbatim as backslash + char.
    buf = _buffer_bytes(data);
    n = len(buf);
    mode = "strict";
    if errors is not None {
        mode = errors as str;
    }
    out: list[int] = [];
    i = 0;
    while i < n {
        b = buf[i];
        if b != 92 {  # '\\'
            out.append(b);
            i = i + 1;
            continue;
        }
        i = i + 1;
        if i == n {
            raise ValueError("Trailing \\ in string");
        }
        c = buf[i];
        i = i + 1;
        if c == 10 {  # '\n': line continuation
            continue;
        }
        if c == 92 { out.append(92); continue; }      # '\\'
        if c == 39 { out.append(39); continue; }      # '\''
        if c == 34 { out.append(34); continue; }      # '"'
        if c == 98 { out.append(8); continue; }       # 'b'
        if c == 102 { out.append(12); continue; }     # 'f'
        if c == 116 { out.append(9); continue; }      # 't'
        if c == 110 { out.append(10); continue; }     # 'n'
        if c == 114 { out.append(13); continue; }     # 'r'
        if c == 118 { out.append(11); continue; }     # 'v'
        if c == 97 { out.append(7); continue; }       # 'a'
        if c >= 48 and c <= 55 {  # '0'..'7': up to three octal digits
            val = c - 48;
            if i < n and buf[i] >= 48 and buf[i] <= 55 {
                val = (val << 3) + buf[i] - 48;
                i = i + 1;
                if i < n and buf[i] >= 48 and buf[i] <= 55 {
                    val = (val << 3) + buf[i] - 48;
                    i = i + 1;
                }
            }
            # char assignment truncates past 0o377 (deprecation warning not
            # re-emitted, see header).
            out.append(val & 0xFF);
            continue;
        }
        if c == 120 {  # 'x'
            ok = False;
            if i + 1 < n {
                d1 = _hex_digit(buf[i]);
                d2 = _hex_digit(buf[i + 1]);
                if d1 < 16 and d2 < 16 {
                    out.append((d1 << 4) + d2);
                    i = i + 2;
                    ok = True;
                }
            }
            if not ok {
                pos = i - 2;  # index of the backslash
                if mode == "strict" {
                    raise ValueError(
                        "invalid \\x escape at position " + str(pos));
                }
                if mode == "replace" {
                    out.append(63);
                } elif mode != "ignore" {
                    raise ValueError(
                        "decoding error; unknown error handling code: "
                        + mode);
                }
                # skip \x, plus one hexdigit if present
                if i < n and _hex_digit(buf[i]) < 16 {
                    i = i + 1;
                }
            }
            continue;
        }
        # Unknown escape: keep backslash + character verbatim.
        out.append(92);
        out.append(c);
    }
    return _codec_tuple(bytes(out), n);
}

# _PyLong_DigitValue restricted to hex digits; >= 16 otherwise.
def _hex_digit(b: int) -> int {
    if b >= 48 and b <= 57 {  # '0'..'9'
        return b - 48;
    }
    if b >= 97 and b <= 102 {  # 'a'..'f'
        return b - 87;
    }
    if b >= 65 and b <= 70 {  # 'A'..'F'
        return b - 55;
    }
    return 16;
}

def escape_encode(data: any, errors: any = None) -> tuple[any, int] {
    # _codecs_escape_encode_impl: bytes-only input (clinic subclass_of
    # PyBytes_Type), errors accepted and ignored, four-byte worst-case room
    # asserted via the PY_SSIZE_T_MAX/4 overflow guard.
    if not isinstance(data, bytes) {
        raise TypeError(
            "a bytes-like object is required, not '"
            + type(data).__name__ + "'");
    }
    src = data as bytes;
    size = len(src);
    if size > 2305843009213693951 {  # PY_SSIZE_T_MAX // 4
        raise OverflowError("string is too large to encode");
    }
    out: list[int] = [];
    for k in range(size) {
        c = src[k];
        if c == 39 or c == 92 {  # '\'' or '\\'
            out.append(92);
            out.append(c);
        } elif c == 9 {  # '\t'
            out.append(92);
            out.append(116);
        } elif c == 10 {  # '\n'
            out.append(92);
            out.append(110);
        } elif c == 13 {  # '\r'
            out.append(92);
            out.append(114);
        } elif c < 32 or c >= 127 {
            out.append(92);
            out.append(120);
            out.append(ord("0123456789abcdef"[(c >> 4) & 0xF]));
            out.append(ord("0123456789abcdef"[c & 0xF]));
        } else {
            out.append(c);
        }
    }
    return _codec_tuple(bytes(out), size);
}

def readbuffer_encode(data: any, errors: any = None) -> tuple[any, int] {
    # _codecs_readbuffer_encode_impl: verbatim PyBytes_FromStringAndSize.
    buf = _buffer_bytes(data);
    return _codec_tuple(bytes(buf), len(buf));
}


# ---------------------------------------------------------------------------
# Fixed-function codecs (delegate; all return (result, consumed) tuples)
#

def utf_7_decode(data: any, errors: any = None, final: bool = False) -> any {
    return host_codecs.utf_7_decode(data, errors, final);
}

def utf_8_decode(data: any, errors: any = None, final: bool = False) -> any {
    return host_codecs.utf_8_decode(data, errors, final);
}

def utf_16_decode(data: any, errors: any = None, final: bool = False) -> any {
    return host_codecs.utf_16_decode(data, errors, final);
}

def utf_16_le_decode(data: any, errors: any = None, final: bool = False) -> any {
    return host_codecs.utf_16_le_decode(data, errors, final);
}

def utf_16_be_decode(data: any, errors: any = None, final: bool = False) -> any {
    return host_codecs.utf_16_be_decode(data, errors, final);
}

def utf_16_ex_decode(
    data: any, errors: any = None, byteorder: int = 0, final: bool = False
) -> any {
    return host_codecs.utf_16_ex_decode(data, errors, byteorder, final);
}

def utf_32_decode(data: any, errors: any = None, final: bool = False) -> any {
    return host_codecs.utf_32_decode(data, errors, final);
}

def utf_32_le_decode(data: any, errors: any = None, final: bool = False) -> any {
    return host_codecs.utf_32_le_decode(data, errors, final);
}

def utf_32_be_decode(data: any, errors: any = None, final: bool = False) -> any {
    return host_codecs.utf_32_be_decode(data, errors, final);
}

def utf_32_ex_decode(
    data: any, errors: any = None, byteorder: int = 0, final: bool = False
) -> any {
    return host_codecs.utf_32_ex_decode(data, errors, byteorder, final);
}

def unicode_escape_decode(
    data: any, errors: any = None, final: bool = True
) -> any {
    return host_codecs.unicode_escape_decode(data, errors, final);
}

def raw_unicode_escape_decode(
    data: any, errors: any = None, final: bool = True
) -> any {
    return host_codecs.raw_unicode_escape_decode(data, errors, final);
}

def latin_1_decode(data: any, errors: any = None) -> any {
    return host_codecs.latin_1_decode(data, errors);
}

def ascii_decode(data: any, errors: any = None) -> any {
    return host_codecs.ascii_decode(data, errors);
}

def charmap_decode(
    data: any, errors: any = None, mapping: any = None
) -> any {
    return host_codecs.charmap_decode(data, errors, mapping);
}


# ---------------------------------------------------------------------------
# Fixed-function encoders (delegate; all return (bytes, consumed) tuples)
#

def utf_7_encode(str_: any, errors: any = None) -> any {
    return host_codecs.utf_7_encode(str_, errors);
}

def utf_8_encode(str_: any, errors: any = None) -> any {
    return host_codecs.utf_8_encode(str_, errors);
}

def utf_16_encode(
    str_: any, errors: any = None, byteorder: int = 0
) -> any {
    return host_codecs.utf_16_encode(str_, errors, byteorder);
}

def utf_16_le_encode(str_: any, errors: any = None) -> any {
    return host_codecs.utf_16_le_encode(str_, errors);
}

def utf_16_be_encode(str_: any, errors: any = None) -> any {
    return host_codecs.utf_16_be_encode(str_, errors);
}

def utf_32_encode(
    str_: any, errors: any = None, byteorder: int = 0
) -> any {
    return host_codecs.utf_32_encode(str_, errors, byteorder);
}

def utf_32_le_encode(str_: any, errors: any = None) -> any {
    return host_codecs.utf_32_le_encode(str_, errors);
}

def utf_32_be_encode(str_: any, errors: any = None) -> any {
    return host_codecs.utf_32_be_encode(str_, errors);
}

def unicode_escape_encode(str_: any, errors: any = None) -> any {
    return host_codecs.unicode_escape_encode(str_, errors);
}

def raw_unicode_escape_encode(str_: any, errors: any = None) -> any {
    return host_codecs.raw_unicode_escape_encode(str_, errors);
}

def latin_1_encode(str_: any, errors: any = None) -> any {
    return host_codecs.latin_1_encode(str_, errors);
}

def ascii_encode(str_: any, errors: any = None) -> any {
    return host_codecs.ascii_encode(str_, errors);
}

def charmap_encode(
    str_: any, errors: any = None, mapping: any = None
) -> any {
    return host_codecs.charmap_encode(str_, errors, mapping);
}

def charmap_build(map_: any) -> any {
    # PyUnicode_BuildEncodingMap: str -> decoding map for charmap_*.
    return host_codecs.charmap_build(map_);
}


# ---------------------------------------------------------------------------
# Error handler registry (delegate)
#

def register_error(errors: str, handler: any) {
    # _codecs_register_error_impl: PyCodec_RegisterError.
    host_codecs.register_error(errors, handler);
}

def _unregister_error(errors: str) -> bool {
    # _codecs__unregister_error_impl: True when a custom handler was removed,
    # False when none existed; built-ins raise.
    return host_codecs._unregister_error(errors) as bool;
}

def lookup_error(name: str) -> any {
    # _codecs_lookup_error_impl: PyCodec_LookupError.
    return host_codecs.lookup_error(name);
}
