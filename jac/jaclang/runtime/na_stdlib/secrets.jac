import from _csprng_native { csprng_bytes, to_hex }
import from base64 { urlsafe_b64encode }


def:pub token_bytes(nbytes: int = 32) -> bytes {
    return csprng_bytes(nbytes);
}


def:pub token_hex(nbytes: int = 32) -> str {
    return to_hex(csprng_bytes(nbytes));
}


def:pub token_urlsafe(nbytes: int = 32) -> str {
    data = csprng_bytes(nbytes);
    enc: bytes = urlsafe_b64encode(data);
    k: int = len(enc);
    while k > 0 and enc[k - 1] == 61 {
        k -= 1;
    }
    return enc[0:k].decode();
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
