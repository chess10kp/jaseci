import from _csprng_native { to_hex }
import from _hashlib_native {
    evp_md_for,
    digest_size_for,
    block_size_for,
    hmac_ctx_new,
    hmac_ctx_update,
    hmac_ctx_digest,
    hmac_ctx_clone,
    hmac_ctx_free
}


obj:pub HMAC {
    has _ctx: int,
        digest_size: int,
        block_size: int,
        name: str;

    def update(data: bytes) {
        hmac_ctx_update(self._ctx, data);
    }

    def digest -> bytes {
        return hmac_ctx_digest(self._ctx, self.digest_size);
    }

    def hexdigest -> str {
        return to_hex(self.digest());
    }

    def copy -> HMAC {
        return HMAC(
            _ctx=hmac_ctx_clone(self._ctx),
            digest_size=self.digest_size,
            block_size=self.block_size,
            name=self.name
        );
    }

    def drop {
        if self._ctx != 0 {
            hmac_ctx_free(self._ctx);
            self._ctx = 0;
        }
    }
}


def:pub new(key: bytes, msg: bytes = b"", digestmod: str = "sha256") -> HMAC {
    md: int = evp_md_for(digestmod);
    if md == 0 {
        raise ValueError("unsupported hash type " + digestmod);
    }
    hm = HMAC(
        _ctx=hmac_ctx_new(md, key),
        digest_size=digest_size_for(digestmod),
        block_size=block_size_for(digestmod),
        name="hmac-" + digestmod
    );
    hm.update(msg);
    return hm;
}


def:pub digest(key: bytes, msg: bytes, digest: str) -> bytes {
    return new(key, msg, digest).digest();
}
