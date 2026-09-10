# Product-path facade for _lzma (low-level Python interface to liblzma).
# Reference: CPython 3.14 ``Modules/_lzmamodule.c`` exercised by
# Lib/test/test_lzma.py (suite_routing: test_lzma -> NEEDS-FACADE,
# facade-module:lzma->_lzma).
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original owns the
# liblzma binding directly (lzma_stream + BlocksOutputBuffer + GIL-release
# around lzma_code). This facade delegates the raw codec to the host ``_lzma``
# extension (same liblzma floor the interpreter ships), exactly like bz2.jac
# delegates to host _bz2. The facade owns everything the C source implements
# ABOVE the lzma_code calls: Compressor_new/Decompressor_new argument
# validation in C evaluation order with their byte-exact ValueError texts,
# the flushed/eof/needs_input/unused_data/check bookkeeping and the
# lock-discipline preconditions. catch_lzma_error's LZMAError mapping needs
# no reimplementation: host exceptions cross the bridge with type and
# message intact, so guest except-handlers match _lzma.LZMAError through the
# class proxy below.
#
# Attribute surface note: the C module exposes eof/needs_input/unused_data/
# check as Py_READONLY members. Here they are refreshed from the underlying
# stream after every delegating call, so direct field reads observe the same
# post-call states (including unused_data accumulating tail bytes past EOF).
#
# Known divergence: parse_filter_chain_spec raises TypeError for malformed
# filter entries before liblzma sees them; the FORMAT_ALONE chain-shape check
# below relies on dict.get, so a non-dict entry surfaces AttributeError where
# C raises TypeError. Well-typed inputs observe identical behavior.

import _lzma;


# ---------------- module identity (lzma_exec) ----------------

# PyErr_NewExceptionWithDoc("_lzma.LZMAError", "Call to liblzma failed.", ...);
glob LZMAError = _lzma.LZMAError;


# ---------------- container formats / integrity checks ----------------

glob FORMAT_AUTO = _lzma.FORMAT_AUTO;
glob FORMAT_XZ = _lzma.FORMAT_XZ;
glob FORMAT_ALONE = _lzma.FORMAT_ALONE;
glob FORMAT_RAW = _lzma.FORMAT_RAW;

glob CHECK_NONE = _lzma.CHECK_NONE;
glob CHECK_CRC32 = _lzma.CHECK_CRC32;
glob CHECK_CRC64 = _lzma.CHECK_CRC64;
glob CHECK_SHA256 = _lzma.CHECK_SHA256;
glob CHECK_ID_MAX = _lzma.CHECK_ID_MAX;
glob CHECK_UNKNOWN = _lzma.CHECK_UNKNOWN;


# ---------------- filter IDs / options (ADD_INT_PREFIX_MACRO block) --------

glob FILTER_LZMA1 = _lzma.FILTER_LZMA1;
glob FILTER_LZMA2 = _lzma.FILTER_LZMA2;
glob FILTER_DELTA = _lzma.FILTER_DELTA;
glob FILTER_X86 = _lzma.FILTER_X86;
glob FILTER_IA64 = _lzma.FILTER_IA64;
glob FILTER_ARM = _lzma.FILTER_ARM;
glob FILTER_ARMTHUMB = _lzma.FILTER_ARMTHUMB;
glob FILTER_SPARC = _lzma.FILTER_SPARC;
glob FILTER_POWERPC = _lzma.FILTER_POWERPC;

glob MF_HC3 = _lzma.MF_HC3;
glob MF_HC4 = _lzma.MF_HC4;
glob MF_BT2 = _lzma.MF_BT2;
glob MF_BT3 = _lzma.MF_BT3;
glob MF_BT4 = _lzma.MF_BT4;

glob MODE_FAST = _lzma.MODE_FAST;
glob MODE_NORMAL = _lzma.MODE_NORMAL;

glob PRESET_DEFAULT = _lzma.PRESET_DEFAULT;
glob PRESET_EXTREME = _lzma.PRESET_EXTREME;


# ---- LZMACompressor (_lzma_LZMACompressor_impl / compress / flush) ----------

obj LZMACompressor {
    has flushed: bool = False,
        inner: any = None;

    def compress(data: bytes) -> bytes {
        # _lzma_LZMACompressor_compress_impl: ACQUIRE_LOCK + flushed guard,
        # then the LZMA_RUN loop. The lock serializes threads inside one
        # object; the guest VM holds no per-object locks, so the flushed
        # precondition carries the observable contract.
        if self.flushed {
            raise ValueError("Compressor has been flushed");
        }
        return self.inner.compress(data);
    }

    def flush() -> bytes {
        # _lzma_LZMACompressor_flush_impl: sets flushed BEFORE draining so a
        # reentrant flush() fails even mid-call.
        if self.flushed {
            raise ValueError("Repeated call to flush()");
        }
        self.flushed = True;
        return self.inner.flush();
    }
}

# Defaults mirror Compressor_new/_lzma_LZMADecompressor_impl clinic
# defaults: FORMAT_XZ and FORMAT_AUTO (liblzma ABI values 1 / 0).
def LZMACompressor_new(format: int = 1, check: int = -1, preset: any = None, filters: any = None) -> LZMACompressor {
    # Compressor_new: conflict checks run BEFORE format dispatch.
    if format != FORMAT_XZ and check != -1 and check != CHECK_NONE {
        raise ValueError("Integrity checks are only supported by FORMAT_XZ");
    }
    if preset is not None and filters is not None {
        raise ValueError("Cannot specify both preset and filter chain");
    }
    if format == FORMAT_RAW and filters is None {
        raise ValueError("Must specify filters for FORMAT_RAW");
    }
    if format == FORMAT_ALONE and filters is not None {
        # Compressor_init_alone: alone encoder accepts exactly one LZMA1
        # filter; anything else is rejected before liblzma is consulted.
        ok = len(filters) == 1;
        if ok {
            ok = filters[0].get("id") == FILTER_LZMA1;
        }
        if not ok {
            raise ValueError(
                "Invalid filter chain for FORMAT_ALONE - "
                + "must be a single LZMA1 filter"
            );
        }
    }
    c = LZMACompressor();
    c.inner = _lzma.LZMACompressor(format, check, preset, filters);
    return c;
}


# ---- LZMADecompressor (_lzma_LZMADecompressor_impl / decompress) ------------

obj LZMADecompressor {
    has eof: bool = False,
        needs_input: bool = True,
        unused_data: bytes = b"",
        check: int = 16,
        inner: any = None;

    def _sync_members {
        # Mirror the Py_READONLY member states after a delegating call.
        self.eof = self.inner.eof;
        self.needs_input = self.inner.needs_input;
        self.unused_data = self.inner.unused_data;
        self.check = self.inner.check;
    }

    def decompress(data: bytes, max_length: int = -1) -> bytes {
        # _lzma_LZMADecompressor_decompress_impl: ACQUIRE_LOCK + eof guard,
        # then the LZMA_RUN loop. Re-entering lzma_code past EOF is the
        # poisoned-state case the guard exists for.
        if self.eof {
            raise EOFError("Already at end of stream");
        }
        out = self.inner.decompress(data, max_length);
        self._sync_members();
        return out;
    }
}

def LZMADecompressor_new(format: int = 0, memlimit: any = None, filters: any = None) -> LZMADecompressor {
    # _lzma_LZMADecompressor_impl: memlimit/filters cross-validation runs
    # before allocation. check starts at CHECK_UNKNOWN (16); FORMAT_ALONE
    # and FORMAT_RAW streams have no check to report, matching the C
    # constructor seeding them with LZMA_CHECK_NONE after delegation syncs.
    if memlimit is not None and format == FORMAT_RAW {
        raise ValueError("Cannot specify memory limit with FORMAT_RAW");
    }
    if format == FORMAT_RAW and filters is None {
        raise ValueError("Must specify filters for FORMAT_RAW");
    }
    elif format != FORMAT_RAW and filters is not None {
        raise ValueError("Cannot specify filters except with FORMAT_RAW");
    }
    d = LZMADecompressor();
    d.inner = _lzma.LZMADecompressor(format, memlimit, filters);
    d._sync_members();
    return d;
}


# ---- Module-level functions (lzma_methods) ----------------------------------

def is_check_supported(check_id: int) -> bool {
    # _lzma_is_check_supported_impl: always True for NONE/CRC32 on builds
    # with check support; the host answers from lzma_check_is_supported.
    return _lzma.is_check_supported(check_id);
}

def _encode_filter_properties(filter: dict) -> any {
    # _lzma__encode_filter_properties: filter spec dict minus its "id" entry
    # encoded to raw lzma properties bytes.
    return _lzma._encode_filter_properties(filter);
}

def _decode_filter_properties(filter_id: int, properties: bytes) -> any {
    # _lzma__decode_filter_properties: inverse of _encode_filter_properties.
    return _lzma._decode_filter_properties(filter_id, properties);
}
