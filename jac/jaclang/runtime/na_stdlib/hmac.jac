import from _hex { to_hex }
import from _hashlib_native {
    evp_md_for,
    digest_size_for,
    block_size_for,
    ctx_require,
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
        ctx_require(self._ctx, "hmac");
        hmac_ctx_update(self._ctx, data);
    }

    def digest -> bytes {
        ctx_require(self._ctx, "hmac");
        return hmac_ctx_digest(self._ctx);
    }

    def hexdigest -> str {
        return to_hex(self.digest());
    }

    def copy -> HMAC {
        ctx_require(self._ctx, "hmac");
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


def:pub new(key: bytes, msg: (bytes | None) = None, digestmod: str = "") -> HMAC {
    if digestmod == "" {
        raise TypeError("Missing required argument 'digestmod'.");
    }
    md: int = evp_md_for(digestmod);
    if md == 0 {
        raise ValueError("unsupported hash type " + digestmod);
    }
    data: bytes = b"";
    if isinstance(msg, bytes) {
        data = msg;
    }
    hm = HMAC(
        _ctx=hmac_ctx_new(md, key),
        digest_size=digest_size_for(digestmod),
        block_size=block_size_for(digestmod),
        name="hmac-" + digestmod
    );
    hm.update(data);
    return hm;
}


def:pub digest(key: bytes, msg: bytes, digest: str) -> bytes {
    return new(key, msg, digest).digest();
}


def:pub compare_digest(a: bytes, b: bytes) -> bool {
    same: bool = len(a) == len(b);
    left: bytes = b;
    diff: int = 1;
    if same {
        left = a;
        diff = 0;
    }
    i: int = 0;
    while i < len(b) {
        diff = diff | (left[i] ^ b[i]);
        i += 1;
    }
    return diff == 0;
}
