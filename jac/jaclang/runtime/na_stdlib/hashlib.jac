import from _csprng_native { to_hex }
import from _hashlib_native {
    evp_md_for,
    digest_size_for,
    block_size_for,
    evp_ctx_new,
    evp_ctx_update,
    evp_ctx_digest,
    evp_ctx_clone,
    evp_ctx_free
}


obj:pub Hash {
    has _ctx: int,
        digest_size: int,
        block_size: int,
        name: str;

    def update(data: bytes) {
        evp_ctx_update(self._ctx, data);
    }

    def digest -> bytes {
        return evp_ctx_digest(self._ctx, self.digest_size);
    }

    def hexdigest -> str {
        return to_hex(self.digest());
    }

    def copy -> Hash {
        return Hash(
            _ctx=evp_ctx_clone(self._ctx),
            digest_size=self.digest_size,
            block_size=self.block_size,
            name=self.name
        );
    }

    def drop {
        if self._ctx != 0 {
            evp_ctx_free(self._ctx);
            self._ctx = 0;
        }
    }
}


def:priv new(name: str, data: bytes = b"") -> Hash {
    md: int = evp_md_for(name);
    if md == 0 {
        raise ValueError("unsupported hash type " + name);
    }
    h = Hash(
        _ctx=evp_ctx_new(md),
        digest_size=digest_size_for(name),
        block_size=block_size_for(name),
        name=name
    );
    h.update(data);
    return h;
}


def:pub md5(data: bytes = b"") -> Hash {
    return new("md5", data);
}


def:pub sha1(data: bytes = b"") -> Hash {
    return new("sha1", data);
}


def:pub sha224(data: bytes = b"") -> Hash {
    return new("sha224", data);
}


def:pub sha256(data: bytes = b"") -> Hash {
    return new("sha256", data);
}


def:pub sha384(data: bytes = b"") -> Hash {
    return new("sha384", data);
}


def:pub sha512(data: bytes = b"") -> Hash {
    return new("sha512", data);
}


def:pub sha3_256(data: bytes = b"") -> Hash {
    return new("sha3_256", data);
}


def:pub sha3_512(data: bytes = b"") -> Hash {
    return new("sha3_512", data);
}
