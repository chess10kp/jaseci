# Product-path facade for _bz2 (low-level Python interface to libbzip2).
# Semantics mirror CPython 3.14 ``Modules/_bz2module.c``: the BZ2Compressor /
# BZ2Decompressor incremental state machines, clinic argument validation and
# byte-exact error strings.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original owns the
# libbz2 binding directly (bz_stream + BlocksOutputBuffer + GIL-release
# around BZ2_bzCompress/bzDecompress). This facade delegates the raw codec to
# the host ``_bz2`` extension (same libbz2 floor the interpreter ships),
# exactly like C-extension modules stay host-proxied on the import path. The
# facade owns everything the C source implements ABOVE the bzlib calls:
# compresslevel validation, flushed/eof/needs_input/unused_data bookkeeping,
# lock-discipline preconditions and their exact ValueError/EOFError texts.
# catch_bz2_error's OSError/EOFError mapping needs no reimplementation: host
# exceptions cross the bridge with type and message intact.
#
# Attribute surface note: the C module exposes eof/unused_data/needs_input as
# Py_READONLY members. Here they are refreshed from the underlying stream
# after every delegating call, so direct field reads observe the same
# post-call states (including unused_data accumulating tail bytes past EOF).

import _bz2;


# ---- BZ2Compressor (_bz2_BZ2Compressor_impl / compress / flush) -------------

obj BZ2Compressor {
    has flushed: bool = False,
        inner: any = None;

    def compress(data: bytes) -> bytes {
        # _bz2_BZ2Compressor_compress_impl: ACQUIRE_LOCK + flushed guard,
        # then the BZ_RUN loop. The lock serializes threads inside one
        # object; the guest VM holds no per-object locks, so the flushed
        # precondition carries the observable contract.
        if self.flushed {
            raise ValueError("Compressor has been flushed");
        }
        return self.inner.compress(data);
    }

    def flush() -> bytes {
        # _bz2_BZ2Compressor_flush_impl: sets flushed BEFORE draining so a
        # reentrant flush() fails even mid-call.
        if self.flushed {
            raise ValueError("Repeated call to flush()");
        }
        self.flushed = True;
        return self.inner.flush();
    }
}

def BZ2Compressor_new(compresslevel: int = 9) -> BZ2Compressor {
    # _bz2_BZ2Compressor_impl: range-checked before any allocation.
    if not (1 <= compresslevel and compresslevel <= 9) {
        raise ValueError("compresslevel must be between 1 and 9");
    }
    c = BZ2Compressor();
    c.inner = _bz2.BZ2Compressor(compresslevel);
    return c;
}


# ---- BZ2Decompressor (_bz2_BZ2Decompressor_impl / decompress) ---------------

obj BZ2Decompressor {
    has eof: bool = False,
        needs_input: bool = True,
        unused_data: bytes = b"",
        inner: any = None;

    def _sync_members {
        # Mirror the Py_READONLY member states after a delegating call.
        self.eof = self.inner.eof;
        self.needs_input = self.inner.needs_input;
        self.unused_data = self.inner.unused_data;
    }

    def decompress(data: bytes, max_length: int = -1) -> bytes {
        # _bz2_BZ2Decompressor_decompress_impl: eof guard first, then the
        # poisoned-after-error guard (re-entering bzDecompress after an
        # error can write out of bounds).
        if self.eof {
            raise EOFError("End of stream already reached");
        }
        out = self.inner.decompress(data, max_length);
        self._sync_members();
        return out;
    }
}

def BZ2Decompressor_new() -> BZ2Decompressor {
    # _bz2_BZ2Decompressor_impl: zeroed state, needs_input=True,
    # unused_data=b''.
    d = BZ2Decompressor();
    d.inner = _bz2.BZ2Decompressor();
    d._sync_members();
    return d;
}
