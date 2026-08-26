# Product-path facade for _hmac (CPython 3.14 Modules/hmacmodule.c).
# Semantics mirror the pinned reference: the static hash-info table
# (py_hmac_static_hinfo), name resolution with lowercase fallback
# (find_hash_info_by_name), _hmac.new argument validation and error texts,
# the HMAC attribute surface (name/block_size/digest_size getters,
# copy/update/digest/hexdigest) and the one-shot compute_* family.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original computes
# through HACL* streaming state directly; this facade delegates the raw HMAC
# floor to the host ``_hashlib`` extension (hmac_new/hmac_digest), exactly like
# bz2.jac delegates its codec to host _bz2. The facade owns everything the C
# source implements ABOVE the raw computation: the alias table, display-name
# synthesis ("hmac-<hashlib name>"), UnknownHashError classification and the
# byte-exact TypeError text for a missing digestmod.
#
# Known divergences:
# - The HACL* UINT32_MAX guards ("key length exceeds 4294967295" /
#   "message length exceeds 4294967295") are unreachable through the OpenSSL
#   floor, so >4GiB inputs do not reproduce those OverflowErrors.
# - new()'s digestmod sentinel is None here; CPython distinguishes an omitted
#   argument from an explicit None only at the clinic layer.
# - repr renders id(self) as a plain 0x hex literal instead of the platform
#   %p format.
#
# Exception mapping: CPython raises ``_hmac.UnknownHashError`` (a ValueError
# subclass); the bridge-table registry carries the hierarchy while this module
# raises ValueError with the byte-exact message. Buffer validation happens on
# the host floor, so TypeError/OverflowError texts cross verbatim.

import from exceptions_core { register_module_exception }
import _hashlib;


# --- Static hash-info entries (py_hmac_static_hinfo) -------------------------
#
# Per-entry lookup generated on demand (no table literal): each entry carries
# the HACL*-style canonical name, the hashlib display name (e->hashlib_name
# when present, else e->name), the block size and the digest size.
# Returns None for unknown kinds.
def hinfo_entry(canonical: str) -> list | None {
    if canonical == "md5" { return ["md5", 64, 16]; }
    if canonical == "sha1" { return ["sha1", 64, 20]; }
    if canonical == "sha2_224" { return ["sha224", 64, 28]; }
    if canonical == "sha2_256" { return ["sha256", 64, 32]; }
    if canonical == "sha2_384" { return ["sha384", 128, 48]; }
    if canonical == "sha2_512" { return ["sha512", 128, 64]; }
    if canonical == "sha3_224" { return ["sha3_224", 144, 28]; }
    if canonical == "sha3_256" { return ["sha3_256", 136, 32]; }
    if canonical == "sha3_384" { return ["sha3_384", 104, 48]; }
    if canonical == "sha3_512" { return ["sha3_512", 72, 64]; }
    if canonical == "blake2s_32" { return ["blake2s", 64, 32]; }
    if canonical == "blake2b_32" { return ["blake2b", 128, 64]; }
    return None;
}


def _py_repr(v: any) -> str {
    # PyErr_Format "%R" analog for unsupported-hash-type messages.
    return repr(v);
}

# find_hash_info: named algorithms only (find_hash_info_impl supports no
# other input kind yet), with the case-insensitive retry.
def find_hash_info(hash_info_ref: any) -> list | None {
    if isinstance(hash_info_ref, str) {
        name = hash_info_ref as str;
        info = hinfo_entry(name);
        if info is not None {
            return info;
        }
        info = hinfo_entry(name.lower());
        if info is not None {
            return info;
        }
    }
    raise ValueError(
        "unsupported hash type: " + _py_repr(hash_info_ref));
}


# --- HMAC object ------------------------------------------------------------

obj HMAC {
    # Immutable after construction, like the C getsets reading stored fields.
    has inner: any = None,
        name: str = "",
        display_name: str = "",
        block_size: int = 0,
        digest_size: int = 0;

    def update(msg: bytes) {
        # GET_BUFFER_VIEW_OR_ERROUT happens on the host floor.
        self.inner.update(msg);
    }

    def digest -> bytes {
        return self.inner.digest();
    }

    def hexdigest -> str {
        return self.inner.hexdigest();
    }

    def copy -> HMAC {
        c = HMAC();
        c.inner = self.inner.copy();
        c.name = self.name;
        c.display_name = self.display_name;
        c.block_size = self.block_size;
        c.digest_size = self.digest_size;
        return c;
    }

    def __repr__ -> str {
        # HMACObject_repr: "<%U HMAC object @ %p>".
        return "<" + self.name + " HMAC object @ " + hex(id(self)) + ">";
    }
}

def new(key: bytes, msg: any = None, digestmod: any = None) -> HMAC {
    # _hmac_new_impl: missing digestmod is a TypeError before any lookup.
    if digestmod is None {
        raise TypeError("new() missing 1 required argument 'digestmod'");
    }
    info = find_hash_info(digestmod);
    if info is None {
        raise ValueError(
            "unsupported hash type: " + _py_repr(digestmod));
    }
    display = info[0] as str;
    h = HMAC();
    h.display_name = display;
    h.name = "hmac-" + display;
    h.block_size = info[1] as int;
    h.digest_size = info[2] as int;
    h.inner = _hashlib.hmac_new(key, msg, display);
    return h;
}


# --- One-shot interface ------------------------------------------------------

def compute_digest(key: bytes, msg: bytes, digest: any) -> bytes {
    # One-shot dispatcher: resolve the name on this side so unknown hashes
    # raise UnknownHashError before touching the floor, then delegate.
    info = find_hash_info(digest);
    if info is None {
        raise ValueError(
            "unsupported hash type: " + _py_repr(digest));
    }
    return _hashlib.hmac_digest(key, msg, info[0] as str);
}

# Py_HMAC_HACL_ONESHOT family, in hmacmodule_methods order. All route through
# the same floor call because hmac_digest(key, msg, name) is value-identical
# to the per-kind HACL* one-shots.
def compute_md5(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "md5");
}

def compute_sha1(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "sha1");
}

def compute_sha2_224(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "sha224");
}

def compute_sha2_256(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "sha256");
}

def compute_sha2_384(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "sha384");
}

def compute_sha2_512(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "sha512");
}

def compute_sha3_224(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "sha3_224");
}

def compute_sha3_256(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "sha3_256");
}

def compute_sha3_384(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "sha3_384");
}

def compute_sha3_512(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "sha3_512");
}

def compute_blake2s_32(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "blake2s");
}

def compute_blake2b_32(key: bytes, msg: bytes) -> bytes {
    return _hashlib.hmac_digest(key, msg, "blake2b");
}


with entry {
    # Module-exception declaration (bridge-table registry, exceptions_core):
    # UnknownHashError subclasses ValueError per Modules/hmacmodule.c
    # (ADD_EXC(unknown_hash_error, "UnknownHashError", PyExc_ValueError)).
    register_module_exception("_hmac.UnknownHashError", "ValueError");
}
