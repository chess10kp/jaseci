import from _csprng_native { csprng_bytes, to_hex }
import from base64 { urlsafe_b64encode }
import from hmac { compare_digest as _hmac_compare_digest }

glob:pub DEFAULT_ENTROPY: int = 32;


def:pub compare_digest(a: bytes, b: bytes) -> bool {
    return _hmac_compare_digest(a, b);
}


def:pub token_bytes(nbytes: (int | None) = None) -> bytes {
    n: int = DEFAULT_ENTROPY;
    if isinstance(nbytes, int) {
        n = nbytes;
    }
    return csprng_bytes(n);
}


def:pub token_hex(nbytes: (int | None) = None) -> str {
    return to_hex(token_bytes(nbytes));
}


def:pub token_urlsafe(nbytes: (int | None) = None) -> str {
    return urlsafe_b64encode(token_bytes(nbytes)).decode().rstrip("=");
}


def:pub randbelow(exclusive_upper_bound: int) -> int {
    if exclusive_upper_bound <= 0 {
        raise ValueError("Upper bound must be positive.");
    }
    bits: int = 0;
    t: int = exclusive_upper_bound;
    while t > 0 {
        bits += 1;
        t = t >> 1;
    }
    nbytes: int = (bits + 7) // 8;
    mask: int = (1 << bits) - 1;

    r: int = exclusive_upper_bound;
    while r >= exclusive_upper_bound {
        data = csprng_bytes(nbytes);
        r = 0;
        i: int = 0;
        while i < nbytes {
            r = (r << 8) | data[i];
            i += 1;
        }
        r = r & mask;
    }
    return r;
}
