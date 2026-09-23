obj:pub AddressValueError(ValueError) {}

obj:pub NetmaskValueError(ValueError) {}

glob:pub IPV4LENGTH: int = 32,
     IPV6LENGTH: int = 128;


def _is_digit_str(s: str) -> bool {
    if len(s) == 0 {
        return False;
    }
    for i in range(len(s)) {
        c = s[i];
        if c < "0" or c > "9" {
            return False;
        }
    }
    return True;
}


def _is_hex_str(s: str) -> bool {
    if len(s) == 0 {
        return False;
    }
    for i in range(len(s)) {
        c = s[i];
        if not (
            (c >= "0" and c <= "9")
            or (c >= "a" and c <= "f")
            or (c >= "A" and c <= "F")
        ) {
            return False;
        }
    }
    return True;
}


def _hexval(c: str) -> int {
    if c >= "0" and c <= "9" {
        return ord(c) - 48;
    }
    if c >= "a" and c <= "f" {
        return ord(c) - 87;
    }
    return ord(c) - 55;
}


def _hexdigit(v: int) -> str {
    if v < 10 {
        return chr(48 + v);
    }
    return chr(87 + v);
}


def _repr_str(s: str) -> str {
    has_q = False;
    has_nl = False;
    for i in range(len(s)) {
        if s[i] == "'" {
            has_q = True;
        }
        if s[i] == "\n" {
            has_nl = True;
        }
    }
    quote = "'";
    if has_q {
        quote = "\"";
    }
    out = quote;
    for i in range(len(s)) {
        c = s[i];
        if c == quote or c == "\\" {
            out += "\\" + c;
        } elif c == "\n" {
            out += "\\n";
        } elif c == "\r" {
            out += "\\r";
        } elif c == "\t" {
            out += "\\t";
        } else {
            out += c;
        }
    }
    return out + quote;
}


def _repr_any(v: any) -> str {
    if isinstance(v, str) {
        return _repr_str(v);
    }
    if isinstance(v, bytes) {
        return "b" + _repr_str(v.decode());
    }
    if isinstance(v, bool) {
        return "True" if v else "False";
    }
    return str(v);
}


def _repr_bytes(b: bytes) -> str {
    out = "b'";
    for i in range(len(b)) {
        c = b[i];
        if c == 39 {
            out += "\\'";
        } elif c == 92 {
            out += "\\\\";
        } elif c == 9 {
            out += "\\t";
        } elif c == 10 {
            out += "\\n";
        } elif c == 13 {
            out += "\\r";
        } elif c < 32 or c >= 127 {
            out += "\\x" + _hexdigit(c // 16) + _hexdigit(c % 16);
        } else {
            out += chr(c);
        }
    }
    return out + "'";
}


def _to_bytes_be(v: int, n: int) -> bytes {
    out = bytearray(n);
    i = n - 1;
    x = v;
    while i >= 0 {
        out[i] = x & 255;
        x = x >> 8;
        i -= 1;
    }
    return bytes(out);
}


def _blen(v: u64) -> int {
    n = 0;
    x = v;
    while x != u64(0) {
        x = x >> u64(1);
        n += 1;
    }
    return n;
}


def _rzb64(v: u64) -> int {
    if v == u64(0) {
        return 64;
    }
    return _blen(~v & wrapping_sub(v, u64(1)));
}


def _cmp128(ahi: u64, alo: u64, bhi: u64, blo: u64) -> int {
    if ahi != bhi {
        if ahi < bhi {
            return -1;
        }
        return 1;
    }
    if alo != blo {
        if alo < blo {
            return -1;
        }
        return 1;
    }
    return 0;
}


def _topmask(k: int) -> u64 {
    if k <= 0 {
        return u64(0);
    }
    if k >= 64 {
        return u64(0xffffffffffffffff);
    }
    return wrapping_shl(u64(0xffffffffffffffff), u64(64 - k));
}


def _mask128(hi: u64, lo: u64, p: int) -> tuple[(u64, u64)] {
    if p <= 0 {
        return (u64(0), u64(0));
    }
    if p < 64 {
        return (hi & _topmask(p), u64(0));
    }
    if p < 128 {
        return (hi, lo & _topmask(p - 64));
    }
    return (hi, lo);
}


def _add128(hi: u64, lo: u64, d: u64) -> tuple[(u64, u64)] {
    nl = wrapping_add(lo, d);
    carry = u64(0);
    if nl < lo {
        carry = u64(1);
    }
    return (wrapping_add(hi, carry), nl);
}


def _sub128(ahi: u64, alo: u64, bhi: u64, blo: u64) -> tuple[(u64, u64)] {
    nl = wrapping_sub(alo, blo);
    borrow = u64(0);
    if alo < blo {
        borrow = u64(1);
    }
    return (wrapping_sub(wrapping_sub(ahi, bhi), borrow), nl);
}


def _adds128(hi: u64, lo: u64, d: int) -> tuple[(u64, u64)] {
    if d >= 0 {
        return _add128(hi, lo, u64(d));
    }
    return _sub128(hi, lo, u64(0), u64(-d));
}


def _shl16_128(hi: u64, lo: u64) -> tuple[(u64, u64)] {
    nhi = wrapping_shl(hi, 16) | (lo >> u64(48));
    nlo = wrapping_shl(lo, 16);
    return (nhi, nlo);
}


def _shl1_128(n: int) -> tuple[(u64, u64)] {
    if n <= 0 {
        return (u64(0), u64(1));
    }
    if n < 64 {
        return (u64(0), wrapping_shl(u64(1), u64(n)));
    }
    if n < 128 {
        return (wrapping_shl(u64(1), u64(n - 64)), u64(0));
    }
    return (u64(0), u64(0));
}


def _ip4_from_str(ip_str: str) -> int {
    if len(ip_str) == 0 {
        raise AddressValueError("Address cannot be empty");
    }
    octets = ip_str.split(".");
    if len(octets) != 4 {
        raise AddressValueError("Expected 4 octets in " + _repr_str(ip_str));
    }
    result = 0;
    for o in octets {
        if len(o) == 0 {
            raise AddressValueError(
                "Empty octet not permitted in " + _repr_str(ip_str)
            );
        }
        if not _is_digit_str(o) {
            raise AddressValueError(
                "Only decimal digits permitted in "
                    + _repr_str(o)
                    + " in "
                    + _repr_str(ip_str)
            );
        }
        if len(o) > 3 {
            raise AddressValueError(
                "At most 3 characters permitted in "
                    + _repr_str(o)
                    + " in "
                    + _repr_str(ip_str)
            );
        }
        if o != "0" and o[0] == "0" {
            raise AddressValueError(
                "Leading zeros are not permitted in "
                    + _repr_str(o)
                    + " in "
                    + _repr_str(ip_str)
            );
        }
        ov = int(o);
        if ov > 255 {
            raise AddressValueError(
                "Octet " + str(ov) + " (> 255) not permitted in " + _repr_str(ip_str)
            );
        }
        result = (result << 8) | ov;
    }
    return result;
}


def _ip4_to_str(ip: int) -> str {
    return str((ip >> 24) & 255)
        + "."
        + str((ip >> 16) & 255)
        + "."
        + str((ip >> 8) & 255)
        + "."
        + str(ip & 255);
}


def _v4_packed(ip: int) -> bytes {
    return _to_bytes_be(ip, 4);
}


def _split_scope_id(ip_str: str) -> tuple[(str, str)] {
    idx = ip_str.find("%");
    if idx == -1 {
        return (ip_str, "");
    }
    addr = ip_str[0:idx];
    scope = ip_str[idx + 1:len(ip_str)];
    if len(scope) == 0 or scope.find("%") != -1 {
        raise AddressValueError("Invalid IPv6 address: \"" + _repr_str(ip_str) + "\"");
    }
    return (addr, scope);
}


def _ip6_from_str(full_str: str) -> tuple[(u64, u64, str)] {
    (ip_str, scope) = _split_scope_id(full_str);
    if len(ip_str) == 0 {
        raise AddressValueError("Address cannot be empty");
    }
    if len(ip_str) > 45 {
        shorten = ip_str;
        if len(shorten) > 100 {
            shorten = ip_str[0:45]
                + "("
                + str(len(ip_str) - 90)
                + " chars elided)"
                + ip_str[len(ip_str) - 45:];
        }
        raise AddressValueError(
            "At most 45 characters expected in " + _repr_str(shorten)
        );
    }
    parts = ip_str.split(":", 9);
    if len(parts) < 3 {
        raise AddressValueError("At least 3 parts expected in " + _repr_str(ip_str));
    }
    last = parts[len(parts) - 1];
    if last.find(".") != -1 {
        try {
            ipv4_int = _ip4_from_str(last);
        } except AddressValueError as exc {
            raise AddressValueError(str(exc) + " in " + _repr_str(ip_str));
        }
        parts.pop();
        parts.append(_hex4((ipv4_int >> 16) & 0xffff));
        parts.append(_hex4(ipv4_int & 0xffff));
    }
    if len(parts) > 9 {
        raise AddressValueError("At most 8 colons permitted in " + _repr_str(ip_str));
    }
    skip_index = -1;
    for i in range(1, len(parts) - 1) {
        if len(parts[i]) == 0 {
            if skip_index != -1 {
                raise AddressValueError(
                    "At most one '::' permitted in " + _repr_str(ip_str)
                );
            }
            skip_index = i;
        }
    }
    parts_hi = 0;
    parts_lo = 0;
    parts_skipped = 0;
    if skip_index != -1 {
        parts_hi = skip_index;
        parts_lo = len(parts) - skip_index - 1;
        if len(parts[0]) == 0 {
            parts_hi -= 1;
            if parts_hi != 0 {
                raise AddressValueError(
                    "Leading ':' only permitted as part of '::' in " + _repr_str(ip_str)
                );
            }
        }
        if len(parts[len(parts) - 1]) == 0 {
            parts_lo -= 1;
            if parts_lo != 0 {
                raise AddressValueError(
                    "Trailing ':' only permitted as part of '::' in "
                        + _repr_str(ip_str)
                );
            }
        }
        parts_skipped = 8 - (parts_hi + parts_lo);
        if parts_skipped < 1 {
            raise AddressValueError(
                "Expected at most 7 other parts with '::' in " + _repr_str(ip_str)
            );
        }
    } else {
        if len(parts) != 8 {
            raise AddressValueError(
                "Exactly 8 parts expected without '::' in " + _repr_str(ip_str)
            );
        }
        if len(parts[0]) == 0 {
            raise AddressValueError(
                "Leading ':' only permitted as part of '::' in " + _repr_str(ip_str)
            );
        }
        if len(parts[len(parts) - 1]) == 0 {
            raise AddressValueError(
                "Trailing ':' only permitted as part of '::' in " + _repr_str(ip_str)
            );
        }
        parts_hi = len(parts);
        parts_lo = 0;
        parts_skipped = 0;
    }
    hi = u64(0);
    lo = u64(0);
    for i in range(parts_hi) {
        (hi, lo) = _shl16_128(hi, lo);
        lo = lo | u64(_parse_hextet(parts[i], ip_str));
    }
    for i in range(parts_skipped) {
        (hi, lo) = _shl16_128(hi, lo);
    }
    for i in range(len(parts) - parts_lo, len(parts)) {
        (hi, lo) = _shl16_128(hi, lo);
        lo = lo | u64(_parse_hextet(parts[i], ip_str));
    }
    return (hi, lo, scope);
}


def _parse_hextet(hs: str, ip_str: str) -> int {
    if len(hs) == 0 {
        raise AddressValueError(
            "invalid literal for int() with base 16: '' in " + _repr_str(ip_str)
        );
    }
    if not _is_hex_str(hs) {
        raise AddressValueError(
            "Only hex digits permitted in " + _repr_str(hs) + " in " + _repr_str(ip_str)
        );
    }
    if len(hs) > 4 {
        raise AddressValueError(
            "At most 4 characters permitted in "
                + _repr_str(hs)
                + " in "
                + _repr_str(ip_str)
        );
    }
    v = 0;
    for i in range(len(hs)) {
        v = (v << 4) | _hexval(hs[i]);
    }
    return v;
}


def _hex4(v: int) -> str {
    if v == 0 {
        return "0";
    }
    out = "";
    x = v;
    while x > 0 {
        out = _hexdigit(x & 15) + out;
        x = x >> 4;
    }
    return out;
}


def _compress_hextets(hextets: list[str]) -> list[str] {
    best_start = -1;
    best_len = 0;
    cur_start = -1;
    cur_len = 0;
    for index in range(len(hextets)) {
        if hextets[index] == "0" {
            cur_len += 1;
            if cur_start == -1 {
                cur_start = index;
            }
            if cur_len > best_len {
                best_len = cur_len;
                best_start = cur_start;
            }
        } else {
            cur_len = 0;
            cur_start = -1;
        }
    }
    if best_len > 1 {
        best_end = best_start + best_len;
        tail: list[str] = [];
        if best_end == len(hextets) {
            tail.append("");
        }
        out: list[str] = [];
        for i in range(best_start) {
            out.append(hextets[i]);
        }
        out.append("");
        for i in range(best_end, len(hextets)) {
            out.append(hextets[i]);
        }
        for t in tail {
            out.append(t);
        }
        if best_start == 0 {
            out.insert(0, "");
        }
        return out;
    }
    return hextets;
}


def _ip6_to_str(hi: u64, lo: u64) -> str {
    hextets: list[str] = [];
    for shift in range(4) {
        hextets.append(_hex4(int((hi >> u64(48 - shift * 16)) & u64(0xffff))));
    }
    for shift in range(4) {
        hextets.append(_hex4(int((lo >> u64(48 - shift * 16)) & u64(0xffff))));
    }
    hextets = _compress_hextets(hextets);
    out = "";
    for i in range(len(hextets)) {
        if i > 0 {
            out += ":";
        }
        out += hextets[i];
    }
    return out;
}


def _ip6_explode(hi: u64, lo: u64) -> str {
    parts: list[str] = [];
    for shift in range(4) {
        h = int((hi >> u64(48 - shift * 16)) & u64(0xffff));
        parts.append(
            _hexdigit((h >> 12) & 15)
                + _hexdigit((h >> 8) & 15)
                + _hexdigit((h >> 4) & 15)
                + _hexdigit(h & 15)
        );
    }
    for shift in range(4) {
        h = int((lo >> u64(48 - shift * 16)) & u64(0xffff));
        parts.append(
            _hexdigit((h >> 12) & 15)
                + _hexdigit((h >> 8) & 15)
                + _hexdigit((h >> 4) & 15)
                + _hexdigit(h & 15)
        );
    }
    out = "";
    for i in range(len(parts)) {
        if i > 0 {
            out += ":";
        }
        out += parts[i];
    }
    return out;
}


def _split_optional_netmask(address: str) -> list[str] {
    addr = address.split("/");
    if len(addr) > 2 {
        raise AddressValueError("Only one '/' permitted in " + _repr_str(address));
    }
    return addr;
}


def _count_rzb128(hi: u64, lo: u64, bits: int) -> int {
    if lo == u64(0) {
        n = 64 + _rzb64(hi);
    } else {
        n = _rzb64(lo);
    }
    if n > bits {
        return bits;
    }
    return n;
}


def _check_int_address(address: int, version: int) {
    max_prefix = 32;
    if version == 6 {
        max_prefix = 128;
    }
    if address < 0 {
        raise AddressValueError(
            str(address)
                + " (< 0) is not permitted as an IPv"
                + str(version)
                + " address"
        );
    }
    if version == 4 and address > 4294967295 {
        raise AddressValueError(
            str(address) + " (>= 2**32) is not permitted as an IPv4 address"
        );
    }
}


def _check_packed_address(address: bytes, expected_len: int, version: int) {
    address_len = len(address);
    if address_len != expected_len {
        raise AddressValueError(
            _repr_bytes(address)
                + " (len "
                + str(address_len)
                + " != "
                + str(expected_len)
                + ") is not permitted as an IPv"
                + str(version)
                + " address"
        );
    }
}


def _v4_privates -> list[tuple[(int, int)]] {
    return [
        (0, 8),
        (167772160, 8),
        (2130706432, 8),
        (2851995648, 16),
        (2886729728, 12),
        (3221225472, 24),
        (3221225642, 31),
        (3221225984, 24),
        (3232235520, 16),
        (3323068416, 15),
        (3325256704, 24),
        (3405803776, 24),
        (4026531840, 4),
        (4294967295, 32)
    ];
}


def _v4_private_exceptions -> list[tuple[(int, int)]] {
    return [(3221225481, 32), (3221225482, 32)];
}


def _v6_privates -> list[tuple[(u64, u64, int)]] {
    return [
        (u64(0), u64(1), 128),
        (u64(0), u64(0), 128),
        (u64(0), u64(281470681743360), 96),
        (u64(28428538856144896), u64(0), 48),
        (u64(72057594037927936), u64(0), 64),
        (u64(2306124484190404608), u64(0), 23),
        (u64(2306139568115548160), u64(0), 32),
        (u64(2306405959167115264), u64(0), 16),
        (u64(4611404543450677248), u64(0), 20),
        (u64(18158513697557839872), u64(0), 7),
        (u64(18338657682652659712), u64(0), 10)
    ];
}


def _v6_private_exceptions -> list[tuple[(u64, u64, int)]] {
    return [
        (u64(2306124488485371904), u64(1), 128),
        (u64(2306124488485371904), u64(2), 128),
        (u64(2306124497075306496), u64(0), 32),
        (u64(2306124501388230656), u64(0), 48),
        (u64(2306124621629358080), u64(0), 28),
        (u64(2306124690348834816), u64(0), 28)
    ];
}


def _v6_reserved -> list[tuple[(u64, u64, int)]] {
    return [
        (u64(0), u64(0), 8),
        (u64(72057594037927936), u64(0), 8),
        (u64(144115188075855872), u64(0), 7),
        (u64(288230376151711744), u64(0), 6),
        (u64(576460752303423488), u64(0), 5),
        (u64(1152921504606846976), u64(0), 4),
        (u64(4611686018427387904), u64(0), 3),
        (u64(6917529027641081856), u64(0), 3),
        (u64(9223372036854775808), u64(0), 3),
        (u64(11529215046068469760), u64(0), 3),
        (u64(13835058055282163712), u64(0), 3),
        (u64(16140901064495857664), u64(0), 4),
        (u64(17293822569102704640), u64(0), 5),
        (u64(17870283321406128128), u64(0), 6),
        (u64(18302628885633695744), u64(0), 9)
    ];
}


def _mask32(prefix: int) -> u64 {
    if prefix <= 0 {
        return u64(0);
    }
    return wrapping_shl(u64(0xffffffff), u64(32 - prefix));
}


def _in_net32(lo: u64, net_lo: int, prefix: int) -> bool {
    return (lo & _mask32(prefix)) == u64(net_lo);
}


def _in_net128(hi: u64, lo: u64, nhi: u64, nlo: u64, prefix: int) -> bool {
    (mhi, mlo) = _mask128(nhi, nlo, prefix);
    (ahi, alo) = _mask128(hi, lo, prefix);
    return ahi == mhi and alo == mlo;
}


obj _AddrBase {
    has version: int = 0,
        _hi: u64 = u64(0),
        _lo: u64 = u64(0),
        _scope: (str | None) = None;
    has packed: bytes { getter; }
    has compressed: str { getter; }
    has exploded: str { getter; }
    has reverse_pointer: str { getter; }
    has max_prefixlen: int { getter; }
    has is_multicast: bool { getter; }
    has is_reserved: bool { getter; }
    has is_private: bool { getter; }
    has is_global: bool { getter; }
    has is_unspecified: bool { getter; }
    has is_loopback: bool { getter; }
    has is_link_local: bool { getter; }
    has is_site_local: bool { getter; }

    def _v4_mapped_lo -> u64 {
        return self._lo;
    }

    def _ipv4_mapped_ip -> int {
        if self.version != 6 {
            return -1;
        }
        if self._hi != u64(0) {
            return -1;
        }
        if (self._lo >> u64(32)) != u64(0xffff) {
            return -1;
        }
        return int(self._lo & u64(0xffffffff));
    }

    def __int__ -> int {
        if self._hi != u64(0) or self._lo > u64(9223372036854775807) {
            raise OverflowError("IPv6 address does not fit in a native 64-bit int");
        }
        return int(self._lo);
    }

    def __str__ -> str {
        if self.version == 4 {
            return _ip4_to_str(int(self._lo));
        }
        mapped = self._ipv4_mapped_ip();
        out = "";
        if mapped != -1 {
            hi96 = self._hi >> u64(32);
            lo96 = wrapping_shl(self._hi & u64(0xffffffff), 32) | (self._lo >> u64(32));
            out = _ip6_to_str(hi96, lo96) + ":" + _ip4_to_str(mapped);
        } else {
            out = _ip6_to_str(self._hi, self._lo);
        }
        if isinstance(self._scope, str) {
            return out + "%" + self._scope_str();
        }
        return out;
    }

    def __repr__ -> str {
        name = "IPv4Address";
        if self.version == 6 {
            name = "IPv6Address";
        }
        return name + "(" + _repr_str(self.__str__()) + ")";
    }

    def __eq__(other: _AddrBase) -> bool {
        return self.version == other.version
            and self._hi == other._hi
            and self._lo == other._lo
            and self._scope_str() == other._scope_str();
    }

    def __ne__(other: _AddrBase) -> bool {
        return not self.__eq__(other);
    }

    def __lt__(other: _AddrBase) -> bool {
        if self.version != other.version {
            raise TypeError(
                self.__str__()
                    + " and "
                    + other.__str__()
                    + " are not of the same version"
            );
        }
        return _cmp128(self._hi, self._lo, other._hi, other._lo) < 0;
    }

    def __gt__(other: _AddrBase) -> bool {
        if self.version != other.version {
            raise TypeError(
                self.__str__()
                    + " and "
                    + other.__str__()
                    + " are not of the same version"
            );
        }
        return _cmp128(self._hi, self._lo, other._hi, other._lo) > 0;
    }

    def __le__(other: _AddrBase) -> bool {
        if self.version != other.version {
            raise TypeError(
                self.__str__()
                    + " and "
                    + other.__str__()
                    + " are not of the same version"
            );
        }
        return _cmp128(self._hi, self._lo, other._hi, other._lo) <= 0;
    }

    def __ge__(other: _AddrBase) -> bool {
        if self.version != other.version {
            raise TypeError(
                self.__str__()
                    + " and "
                    + other.__str__()
                    + " are not of the same version"
            );
        }
        return _cmp128(self._hi, self._lo, other._hi, other._lo) >= 0;
    }

    def __add__(other: int) -> _AddrBase {
        (nh, nl) = _adds128(self._hi, self._lo, other);
        return _mkaddr(self.version, nh, nl, self._scope_str());
    }

    def __sub__(other: int) -> _AddrBase {
        (nh, nl) = _adds128(self._hi, self._lo, -other);
        return _mkaddr(self.version, nh, nl, self._scope_str());
    }

    def __hash__ -> int {
        h = int(self._hi >> u64(32)) * 131071
            + int(self._hi & u64(0xffffffff)) * 131
            + int(self._lo >> u64(32)) * 8191
            + int(self._lo & u64(0xffffffff)) * 17
            + self.version;
        for i in range(len(self._scope_str())) {
            h = h * 131 + ord(self._scope_str()[i]);
        }
        return h;
    }

    def _scope_str -> str {
        if isinstance(self._scope, str) {
            return self._scope;
        }
        return "";
    }
}


impl _AddrBase.packed.getter -> bytes {
    if self.version == 4 {
        return _v4_packed(int(self._lo));
    }
    out = bytearray(16);
    x = self._hi;
    for i in range(8) {
        out[7 - i] = int(x & u64(255));
        x = x >> u64(8);
    }
    x = self._lo;
    for i in range(8) {
        out[15 - i] = int(x & u64(255));
        x = x >> u64(8);
    }
    return bytes(out);
}


impl _AddrBase.compressed.getter -> str {
    return self.__str__();
}


impl _AddrBase.exploded.getter -> str {
    if self.version == 4 {
        return self.__str__();
    }
    mapped = self._ipv4_mapped_ip();
    raw = _ip6_explode(self._hi, self._lo);
    if mapped == -1 {
        return raw;
    }
    return raw[0:30] + _ip4_to_str(mapped);
}


impl _AddrBase.reverse_pointer.getter -> str {
    if self.version == 4 {
        s = _ip4_to_str(int(self._lo));
        parts = s.split(".");
        out = "";
        for i in range(len(parts)) {
            if i > 0 {
                out += ".";
            }
            out += parts[len(parts) - 1 - i];
        }
        return out + ".in-addr.arpa";
    }
    raw = self.exploded;
    chars = "";
    for i in range(len(raw)) {
        if raw[i] != ":" {
            chars += raw[i];
        }
    }
    out = "";
    for i in range(len(chars)) {
        if i > 0 {
            out += ".";
        }
        out += chars[len(chars) - 1 - i];
    }
    return out + ".ip6.arpa";
}


impl _AddrBase.max_prefixlen.getter -> int {
    if self.version == 4 {
        return 32;
    }
    return 128;
}


impl _AddrBase.is_multicast.getter -> bool {
    mapped = self._ipv4_mapped_ip();
    if mapped != -1 {
        return _in_net32(u64(mapped), 3758096384, 4);
    }
    if self.version == 4 {
        return _in_net32(self._lo, 3758096384, 4);
    }
    return _in_net128(self._hi, self._lo, u64(18374686479671623680), u64(0), 8);
}


impl _AddrBase.is_reserved.getter -> bool {
    mapped = self._ipv4_mapped_ip();
    if mapped != -1 {
        return _in_net32(u64(mapped), 4026531840, 4);
    }
    if self.version == 4 {
        return _in_net32(self._lo, 4026531840, 4);
    }
    for t in _v6_reserved() {
        if _in_net128(self._hi, self._lo, t[0], t[1], t[2]) {
            return True;
        }
    }
    return False;
}


impl _AddrBase.is_private.getter -> bool {
    mapped = self._ipv4_mapped_ip();
    check_hi = self._hi;
    check_lo = self._lo;
    ver = self.version;
    if mapped != -1 {
        check_hi = u64(0);
        check_lo = u64(mapped);
        ver = 4;
    }
    if ver == 4 {
        inside = False;
        for t in _v4_privates() {
            if _in_net32(check_lo, t[0], t[1]) {
                inside = True;
            }
        }
        if not inside {
            return False;
        }
        for t in _v4_private_exceptions() {
            if _in_net32(check_lo, t[0], t[1]) {
                return False;
            }
        }
        return True;
    }
    inside = False;
    for t in _v6_privates() {
        if _in_net128(check_hi, check_lo, t[0], t[1], t[2]) {
            inside = True;
        }
    }
    if not inside {
        return False;
    }
    for t in _v6_private_exceptions() {
        if _in_net128(check_hi, check_lo, t[0], t[1], t[2]) {
            return False;
        }
    }
    return True;
}


impl _AddrBase.is_global.getter -> bool {
    mapped = self._ipv4_mapped_ip();
    if mapped != -1 {
        if _in_net32(u64(mapped), 1681915904, 10) {
            return False;
        }
        ver_lo = mapped;
        inside = False;
        for t in _v4_privates() {
            if _in_net32(u64(ver_lo), t[0], t[1]) {
                inside = True;
            }
        }
        if not inside {
            return True;
        }
        for t in _v4_private_exceptions() {
            if _in_net32(u64(ver_lo), t[0], t[1]) {
                return True;
            }
        }
        return False;
    }
    if self.version == 4 {
        if _in_net32(self._lo, 1681915904, 10) {
            return False;
        }
        return not self.is_private;
    }
    return not self.is_private;
}


impl _AddrBase.is_unspecified.getter -> bool {
    mapped = self._ipv4_mapped_ip();
    if mapped != -1 {
        return mapped == 0;
    }
    return self._hi == u64(0) and self._lo == u64(0);
}


impl _AddrBase.is_loopback.getter -> bool {
    mapped = self._ipv4_mapped_ip();
    if mapped != -1 {
        return _in_net32(u64(mapped), 2130706432, 8);
    }
    if self.version == 4 {
        return _in_net32(self._lo, 2130706432, 8);
    }
    return self._hi == u64(0) and self._lo == u64(1);
}


impl _AddrBase.is_link_local.getter -> bool {
    mapped = self._ipv4_mapped_ip();
    if mapped != -1 {
        return _in_net32(u64(mapped), 2851995648, 16);
    }
    if self.version == 4 {
        return _in_net32(self._lo, 2851995648, 16);
    }
    return _in_net128(self._hi, self._lo, u64(18338657682652659712), u64(0), 10);
}


impl _AddrBase.is_site_local.getter -> bool {
    return False;
}


def _mkaddr(version: int, hi: u64, lo: u64, scope: str) -> _AddrBase {
    if version == 4 {
        a4 = IPv4Address(0);
        a4._lo = lo;
        a4._hi = u64(0);
        return a4;
    }
    a6 = IPv6Address(0);
    a6._hi = hi;
    a6._lo = lo;
    if len(scope) > 0 {
        a6._scope = scope;
    }
    return a6;
}


obj:pub IPv4Address(_AddrBase) {
    has ipv6_mapped: IPv6Address { getter; }

    def init(address: (str | int | bytes)) {
        self.version = 4;
        if isinstance(address, int) {
            _check_int_address(address, 4);
            self._lo = u64(address);
            return;
        }
        if isinstance(address, bytes) {
            _check_packed_address(address, 4, 4);
            self._lo = u64(int.from_bytes(address, "big"));
            return;
        }
        if address.find("/") != -1 {
            raise AddressValueError("Unexpected '/' in " + _repr_str(address));
        }
        self._lo = u64(_ip4_from_str(address));
    }
}


impl IPv4Address.ipv6_mapped.getter -> IPv6Address {
    a = IPv6Address(0);
    a._hi = u64(0);
    a._lo = u64(281470681743360) | self._lo;
    return a;
}


obj:pub IPv6Address(_AddrBase) {
    has scope_id: (str | None) { getter; }
    has ipv4_mapped: (IPv4Address | None) { getter; }
    has teredo: (tuple[(IPv4Address, IPv4Address)] | None) { getter; }
    has sixtofour: (IPv4Address | None) { getter; }
    has is_site_local: bool { getter; }

    def init(address: (str | int | bytes)) {
        self.version = 6;
        if isinstance(address, int) {
            if address < 0 {
                raise AddressValueError(
                    str(address) + " (< 0) is not permitted as an IPv6 address"
                );
            }
            self._hi = u64(0);
            self._lo = u64(address);
            return;
        }
        if isinstance(address, bytes) {
            _check_packed_address(address, 16, 6);
            self._hi = u64(int.from_bytes(address[0:8], "big"));
            self._lo = u64(int.from_bytes(address[8:16], "big"));
            return;
        }
        if address.find("/") != -1 {
            raise AddressValueError("Unexpected '/' in " + _repr_str(address));
        }
        (hi, lo, scope) = _ip6_from_str(address);
        self._hi = hi;
        self._lo = lo;
        if len(scope) > 0 {
            self._scope = scope;
        }
    }

    def _ipv4_mapped_ipv6_to_str -> str {
        mapped = self._ipv4_mapped_ip();
        if mapped == -1 {
            raise AddressValueError(
                "Can not apply to non-IPv4-mapped IPv6 address " + self.__str__()
            );
        }
        hi96 = self._hi >> u64(32);
        lo96 = wrapping_shl(self._hi & u64(0xffffffff), 32) | (self._lo >> u64(32));
        return _ip6_to_str(hi96, lo96) + ":" + _ip4_to_str(mapped);
    }
}


impl IPv6Address.scope_id.getter -> (str | None) {
    return self._scope;
}


impl IPv6Address.ipv4_mapped.getter -> (IPv4Address | None) {
    mapped = self._ipv4_mapped_ip();
    if mapped == -1 {
        return None;
    }
    a = IPv4Address(0);
    a._lo = u64(mapped);
    return a;
}


impl IPv6Address.teredo.getter -> (tuple[(IPv4Address, IPv4Address)] | None) {
    if (self._hi >> u64(32)) != u64(0x20010000) {
        return None;
    }
    server = IPv4Address(0);
    server._lo = self._hi & u64(0xffffffff);
    client = IPv4Address(0);
    client._lo = ~self._lo & u64(0xffffffff);
    return (server, client);
}


impl IPv6Address.sixtofour.getter -> (IPv4Address | None) {
    if (self._hi >> u64(48)) != u64(0x2002) {
        return None;
    }
    a = IPv4Address(0);
    a._lo = (self._hi >> u64(16)) & u64(0xffffffff);
    return a;
}


impl IPv6Address.is_site_local.getter -> bool {
    return _in_net128(self._hi, self._lo, u64(18356672081162141696), u64(0), 10);
}


def _netmask_from_prefix(prefix: int) -> tuple[(u64, u64)] {
    if prefix <= 0 {
        return (u64(0), u64(0));
    }
    if prefix >= 128 {
        return (u64(0xffffffffffffffff), u64(0xffffffffffffffff));
    }
    if prefix >= 64 {
        return (u64(0xffffffffffffffff), _topmask(prefix - 64));
    }
    return (_topmask(prefix), u64(0));
}


def _rzb128_count(hi: u64, lo: u64) -> int {
    if lo == u64(0) {
        return 64 + _rzb64(hi);
    }
    return _rzb64(lo);
}


def _ones128(p: int) -> tuple[(u64, u64)] {
    if p <= 0 {
        return (u64(0), u64(0));
    }
    if p < 64 {
        return (u64(0), wrapping_sub(wrapping_shl(u64(1), u64(p)), u64(1)));
    }
    if p < 128 {
        return (
            wrapping_sub(wrapping_shl(u64(1), u64(p - 64)), u64(1)),
            u64(0xffffffffffffffff)
        );
    }
    return (u64(0xffffffffffffffff), u64(0xffffffffffffffff));
}


def _prefix_from_ip128(hi: u64, lo: u64) -> int {
    trailing = _rzb128_count(hi, lo);
    if trailing > 128 {
        trailing = 128;
    }
    prefixlen = 128 - trailing;
    (e_hi, e_lo) = _ones128(prefixlen);
    (l_hi, l_lo) = _shr128(hi, lo, trailing);
    if l_hi != e_hi or l_lo != e_lo {
        raise ValueError("netmask mixes zeroes & ones");
    }
    return prefixlen;
}


def _rzb32(v: int) -> int {
    if v == 0 {
        return 32;
    }
    n = 0;
    x = v;
    while (x & 1) == 0 {
        x = x >> 1;
        n += 1;
    }
    return n;
}


def _prefix_from_ip32(ip_int: int) -> int {
    trailing = _rzb32(ip_int);
    if trailing > 32 {
        trailing = 32;
    }
    prefixlen = 32 - trailing;
    leading = ip_int >> trailing;
    if leading != (1 << prefixlen) - 1 {
        raise ValueError("netmask mixes zeroes & ones");
    }
    return prefixlen;
}


obj _NetBase {
    has version: int = 0,
        _net_hi: u64 = u64(0),
        _net_lo: u64 = u64(0),
        _mask_hi: u64 = u64(0),
        _mask_lo: u64 = u64(0),
        _prefixlen: int = 0;
    has network_address: _AddrBase { getter; }
    has broadcast_address: _AddrBase { getter; }
    has netmask: _AddrBase { getter; }
    has hostmask: _AddrBase { getter; }
    has prefixlen: int { getter; }
    has num_addresses: int { getter; }
    has with_prefixlen: str { getter; }
    has with_netmask: str { getter; }
    has with_hostmask: str { getter; }
    has is_multicast: bool { getter; }
    has is_reserved: bool { getter; }
    has is_link_local: bool { getter; }
    has is_private: bool { getter; }
    has is_global: bool { getter; }
    has is_unspecified: bool { getter; }
    has is_loopback: bool { getter; }
    has is_site_local: bool { getter; }

    def _maxpl -> int {
        if self.version == 4 {
            return 32;
        }
        return 128;
    }

    def _mk_addr(hi: u64, lo: u64) -> _AddrBase {
        return _mkaddr(self.version, hi, lo, "");
    }

    def _mk_net(nhi: u64, nlo: u64, prefix: int) -> _NetBase {
        return _mknet(self.version, nhi, nlo, prefix);
    }

    def _bcast -> tuple[(u64, u64)] {
        hostmask_hi = ~self._mask_hi;
        hostmask_lo = ~self._mask_lo;
        if self.version == 4 {
            hostmask_hi = u64(0);
            hostmask_lo = hostmask_lo & u64(0xffffffff);
        }
        return (self._net_hi | hostmask_hi, self._net_lo | hostmask_lo);
    }

    def _contains128(hi: u64, lo: u64) -> bool {
        return (hi & self._mask_hi) == self._net_hi
            and (lo & self._mask_lo) == self._net_lo;
    }

    def __contains__(other: _AddrBase) -> bool {
        if self.version != other.version {
            return False;
        }
        return self._contains128(other._hi, other._lo);
    }

    def contains(other: _AddrBase) -> bool {
        return self.__contains__(other);
    }

    def __str__ -> str {
        return self.network_address.__str__() + "/" + str(self._prefixlen);
    }

    def __repr__ -> str {
        name = "IPv4Network";
        if self.version == 6 {
            name = "IPv6Network";
        }
        return name + "(" + _repr_str(self.__str__()) + ")";
    }

    def __eq__(other: _NetBase) -> bool {
        return self.version == other.version
            and self._net_hi == other._net_hi
            and self._net_lo == other._net_lo
            and self._mask_hi == other._mask_hi
            and self._mask_lo == other._mask_lo;
    }

    def __ne__(other: _NetBase) -> bool {
        return not self.__eq__(other);
    }

    def __lt__(other: _NetBase) -> bool {
        if self.version != other.version {
            raise TypeError(
                self.__str__()
                    + " and "
                    + other.__str__()
                    + " are not of the same version"
            );
        }
        c = _cmp128(self._net_hi, self._net_lo, other._net_hi, other._net_lo);
        if c != 0 {
            return c < 0;
        }
        return _cmp128(self._mask_hi, self._mask_lo, other._mask_hi, other._mask_lo)
            < 0;
    }

    def __gt__(other: _NetBase) -> bool {
        if self.version != other.version {
            raise TypeError(
                self.__str__()
                    + " and "
                    + other.__str__()
                    + " are not of the same version"
            );
        }
        c = _cmp128(self._net_hi, self._net_lo, other._net_hi, other._net_lo);
        if c != 0 {
            return c > 0;
        }
        return _cmp128(self._mask_hi, self._mask_lo, other._mask_hi, other._mask_lo)
            > 0;
    }

    def __le__(other: _NetBase) -> bool {
        if self.version != other.version {
            raise TypeError(
                self.__str__()
                    + " and "
                    + other.__str__()
                    + " are not of the same version"
            );
        }
        c = _cmp128(self._net_hi, self._net_lo, other._net_hi, other._net_lo);
        if c != 0 {
            return c < 0;
        }
        return _cmp128(self._mask_hi, self._mask_lo, other._mask_hi, other._mask_lo)
            <= 0;
    }

    def __ge__(other: _NetBase) -> bool {
        if self.version != other.version {
            raise TypeError(
                self.__str__()
                    + " and "
                    + other.__str__()
                    + " are not of the same version"
            );
        }
        c = _cmp128(self._net_hi, self._net_lo, other._net_hi, other._net_lo);
        if c != 0 {
            return c > 0;
        }
        return _cmp128(self._mask_hi, self._mask_lo, other._mask_hi, other._mask_lo)
            >= 0;
    }

    def __hash__ -> int {
        return int(self._net_hi >> u64(32)) * 131071
            + int(self._net_hi & u64(0xffffffff)) * 131
            + int(self._net_lo >> u64(32)) * 8191
            + int(self._net_lo & u64(0xffffffff)) * 17
            + int(self._mask_hi >> u64(32)) * 131
            + int(self._mask_lo & u64(0xffffffff)) * 17
            + self.version;
    }

    def __iter__ -> _AddrIter {
        (bhi, blo) = self._bcast();
        return _AddrIter(
            _hi=self._net_hi,
            _lo=self._net_lo,
            _ehi=bhi,
            _elo=blo,
            _ver=self.version,
            _inclusive=True,
            _done=False
        );
    }

    def hosts -> _AddrIter {
        if self._prefixlen >= self._maxpl() - 1 {
            return self.__iter__();
        }
        (bhi, blo) = self._bcast();
        (shi, slo) = _add128(self._net_hi, self._net_lo, u64(1));
        if self.version == 6 {
            return _AddrIter(
                _hi=shi,
                _lo=slo,
                _ehi=bhi,
                _elo=blo,
                _ver=6,
                _inclusive=True,
                _done=False
            );
        }
        return _AddrIter(
            _hi=shi,
            _lo=slo,
            _ehi=bhi,
            _elo=blo,
            _ver=self.version,
            _inclusive=False,
            _done=False
        );
    }

    def __getitem__(n: int) -> _AddrBase {
        (bhi, blo) = self._bcast();
        if n >= 0 {
            (ahi, alo) = _add128(self._net_hi, self._net_lo, u64(n));
            if _cmp128(ahi, alo, bhi, blo) > 0 {
                raise IndexError("address out of range");
            }
            return self._mk_addr(ahi, alo);
        }
        nn = n + 1;
        (ahi, alo) = _adds128(bhi, blo, nn);
        if _cmp128(ahi, alo, self._net_hi, self._net_lo) < 0 {
            raise IndexError("address out of range");
        }
        return self._mk_addr(ahi, alo);
    }

    def overlaps(other: _NetBase) -> bool {
        (bhi, blo) = self._bcast();
        (obhi, oblo) = other._bcast();
        return other._contains128(self._net_hi, self._net_lo)
            or other._contains128(bhi, blo)
            or self._contains128(other._net_hi, other._net_lo)
            or self._contains128(obhi, oblo);
    }

    def subnet_of(other: _NetBase) -> bool {
        return _is_subnet_of(self, other);
    }

    def supernet_of(other: _NetBase) -> bool {
        return _is_subnet_of(other, self);
    }

    def compare_networks(other: _NetBase) -> int {
        if self.version != other.version {
            raise TypeError(
                self.__str__() + " and " + other.__str__() + " are not of the same type"
            );
        }
        c = _cmp128(self._net_hi, self._net_lo, other._net_hi, other._net_lo);
        if c != 0 {
            return c;
        }
        return _cmp128(self._mask_hi, self._mask_lo, other._mask_hi, other._mask_lo);
    }

    def subnets(
        prefixlen_diff: int = 1, new_prefix: (int | None) = None
    ) -> _SubnetIter {
        if self._prefixlen == self._maxpl() {
            return _SubnetIter(
                _ver=self.version,
                _cur_hi=self._net_hi,
                _cur_lo=self._net_lo,
                _step_hi=0,
                _step_lo=0,
                _end_hi=self._net_hi,
                _end_lo=self._net_lo,
                _prefix=self._prefixlen,
                _done=False,
                _single=True
            );
        }
        diff = prefixlen_diff;
        if isinstance(new_prefix, int) {
            if new_prefix < self._prefixlen {
                raise ValueError("new prefix must be longer");
            }
            if prefixlen_diff != 1 {
                raise ValueError("cannot set prefixlen_diff and new_prefix");
            }
            diff = new_prefix - self._prefixlen;
        }
        if diff < 0 {
            raise ValueError("prefix length diff must be > 0");
        }
        new_prefixlen = self._prefixlen + diff;
        if new_prefixlen > self._maxpl() {
            raise ValueError(
                "prefix length diff "
                    + str(new_prefixlen)
                    + " is invalid for netblock "
                    + self.__str__()
            );
        }
        (bhi, blo) = self._bcast();
        (end_hi, end_lo) = _add128(bhi, blo, u64(1));
        open_end = end_hi == u64(0) and end_lo == u64(0);
        hostmask_size_hi = ~self._mask_hi;
        hostmask_size_lo = ~self._mask_lo;
        if self.version == 4 {
            hostmask_size_hi = u64(0);
            hostmask_size_lo = hostmask_size_lo & u64(0xffffffff);
        }
        (hs_hi, hs_lo) = _add128(hostmask_size_hi, hostmask_size_lo, u64(1));
        (step_hi, step_lo) = _shr128(hs_hi, hs_lo, diff);
        return _SubnetIter(
            _ver=self.version,
            _cur_hi=self._net_hi,
            _cur_lo=self._net_lo,
            _step_hi=step_hi,
            _step_lo=step_lo,
            _end_hi=end_hi,
            _end_lo=end_lo,
            _prefix=new_prefixlen,
            _done=False,
            _open_end=open_end
        );
    }

    def supernet(prefixlen_diff: int = 1, new_prefix: (int | None) = None) -> _NetBase {
        if self._prefixlen == 0 {
            return self;
        }
        diff = prefixlen_diff;
        if isinstance(new_prefix, int) {
            if new_prefix > self._prefixlen {
                raise ValueError("new prefix must be shorter");
            }
            if prefixlen_diff != 1 {
                raise ValueError("cannot set prefixlen_diff and new_prefix");
            }
            diff = self._prefixlen - new_prefix;
        }
        new_prefixlen = self._prefixlen - diff;
        if new_prefixlen < 0 {
            raise ValueError(
                "current prefixlen is "
                    + str(self._prefixlen)
                    + ", cannot have a prefixlen_diff of "
                    + str(diff)
            );
        }
        (nhi, nlo) = _mask128(self._net_hi, self._net_lo, new_prefixlen);
        if self.version == 4 {
            nhi = u64(0);
            nlo = self._net_lo & _mask32(new_prefixlen);
        }
        return self._mk_net(nhi, nlo, new_prefixlen);
    }

    def address_exclude(other: _NetBase) -> Iterator[_NetBase] {
        if self.version != other.version {
            raise TypeError(
                self.__str__()
                    + " and "
                    + other.__str__()
                    + " are not of the same version"
            );
        }
        if not other.subnet_of(self) {
            raise ValueError(other.__str__() + " not contained in " + self.__str__());
        }
        if other.__eq__(self) {
            return iter([]);
        }
        return _exclude_iter(self, other);
    }
}


def _shr128(hi: u64, lo: u64, n: int) -> tuple[(u64, u64)] {
    if n <= 0 {
        return (hi, lo);
    }
    if n >= 128 {
        return (u64(0), u64(0));
    }
    if n >= 64 {
        return (u64(0), hi >> u64(n - 64));
    }
    nlo = (lo >> u64(n)) | wrapping_shl(hi, u64(64 - n));
    nhi = hi >> u64(n);
    return (nhi, nlo);
}


def _lowmask(k: int) -> u64 {
    if k <= 0 {
        return u64(0);
    }
    if k >= 64 {
        return u64(0xffffffffffffffff);
    }
    return wrapping_sub(wrapping_shl(u64(1), u64(k)), u64(1));
}


def _is_subnet_of(a: _NetBase, b: _NetBase) -> bool {
    if a.version != b.version {
        raise TypeError(
            a.__str__() + " and " + b.__str__() + " are not of the same version"
        );
    }
    (abhi, ablo) = a._bcast();
    (bbhi, bblo) = b._bcast();
    return _cmp128(b._net_hi, b._net_lo, a._net_hi, a._net_lo) <= 0
        and _cmp128(bbhi, bblo, abhi, ablo) >= 0;
}


obj _AddrIter {
    has _hi: u64 = u64(0),
        _lo: u64 = u64(0),
        _ehi: u64 = u64(0),
        _elo: u64 = u64(0),
        _ver: int = 4,
        _inclusive: bool = True,
        _done: bool = False;

    def __iter__ -> _AddrIter {
        return self;
    }

    def __next__ -> _AddrBase {
        if self._done {
            raise StopIteration();
        }
        c = _cmp128(self._hi, self._lo, self._ehi, self._elo);
        if self._inclusive {
            if c > 0 {
                self._done = True;
                raise StopIteration();
            }
        } elif c >= 0 {
            self._done = True;
            raise StopIteration();
        }
        a = _mkaddr(self._ver, self._hi, self._lo, "");
        r = _add128(self._hi, self._lo, u64(1));
        self._hi = r[0];
        self._lo = r[1];
        if self._ver == 6 and self._hi == u64(0) and self._lo == u64(0) {
            self._done = True;
        }
        return a;
    }
}


obj _SubnetIter {
    has _ver: int = 4,
        _cur_hi: u64 = u64(0),
        _cur_lo: u64 = u64(0),
        _step_hi: u64 = u64(0),
        _step_lo: u64 = u64(0),
        _end_hi: u64 = u64(0),
        _end_lo: u64 = u64(0),
        _prefix: int = 0,
        _done: bool = False,
        _open_end: bool = False,
        _single: bool = False;

    def __iter__ -> _SubnetIter {
        return self;
    }

    def __next__ -> _NetBase {
        if self._done {
            raise StopIteration();
        }
        if self._single {
            self._done = True;
            return _mknet(self._ver, self._cur_hi, self._cur_lo, self._prefix);
        }
        if not self._open_end
            and _cmp128(self._cur_hi, self._cur_lo, self._end_hi, self._end_lo) >= 0 {
            self._done = True;
            raise StopIteration();
        }
        n = _mknet(self._ver, self._cur_hi, self._cur_lo, self._prefix);
        r = _add128(self._cur_hi, self._cur_lo, self._step_lo);
        self._cur_hi = wrapping_add(r[0], self._step_hi);
        self._cur_lo = r[1];
        if self._cur_hi == u64(0) and self._cur_lo == u64(0) {
            self._done = True;
        }
        return n;
    }
}


def _mknet(version: int, nhi: u64, nlo: u64, prefix: int) -> _NetBase {
    (mhi, mlo) = _netmask_from_prefix(prefix);
    if version == 4 {
        n4 = IPv4Network(0, False);
        n4._net_hi = u64(0);
        n4._net_lo = nlo;
        n4._mask_hi = u64(0);
        n4._mask_lo = _mask32(prefix);
        n4._prefixlen = prefix;
        return n4;
    }
    n6 = IPv6Network(0, False);
    n6._net_hi = nhi;
    n6._net_lo = nlo;
    n6._mask_hi = mhi;
    n6._mask_lo = mlo;
    n6._prefixlen = prefix;
    return n6;
}


def _exclude_iter(net: _NetBase, other: _NetBase) -> Iterator[_NetBase] {
    it = net.subnets();
    s1 = it.__next__();
    s2 = it.__next__();
    while not s1.__eq__(other) and not s2.__eq__(other) {
        if other.subnet_of(s1) {
            yield s2;
            it = s1.subnets();
            s1 = it.__next__();
            s2 = it.__next__();
        } elif other.subnet_of(s2) {
            yield s1;
            it = s2.subnets();
            s1 = it.__next__();
            s2 = it.__next__();
        } else {
            raise RuntimeError("Error performing exclusion");
        }
    }
    if s1.__eq__(other) {
        yield s2;
    } elif s2.__eq__(other) {
        yield s1;
    } else {
        raise RuntimeError("Error performing exclusion");
    }
}


impl _NetBase.network_address.getter -> _AddrBase {
    return self._mk_addr(self._net_hi, self._net_lo);
}


impl _NetBase.broadcast_address.getter -> _AddrBase {
    (bhi, blo) = self._bcast();
    return self._mk_addr(bhi, blo);
}


impl _NetBase.netmask.getter -> _AddrBase {
    return self._mk_addr(self._mask_hi, self._mask_lo);
}


impl _NetBase.hostmask.getter -> _AddrBase {
    hm_hi = ~self._mask_hi;
    hm_lo = ~self._mask_lo;
    if self.version == 4 {
        hm_hi = u64(0);
        hm_lo = hm_lo & u64(0xffffffff);
    }
    return self._mk_addr(hm_hi, hm_lo);
}


impl _NetBase.prefixlen.getter -> int {
    return self._prefixlen;
}


impl _NetBase.num_addresses.getter -> int {
    (bhi, blo) = self._bcast();
    (dhi, dlo) = _sub128(bhi, blo, self._net_hi, self._net_lo);
    if dhi != u64(0) or dlo > u64(9223372036854775807) {
        raise OverflowError("network size does not fit in a native 64-bit int");
    }
    return int(dlo) + 1;
}


impl _NetBase.with_prefixlen.getter -> str {
    return self.__str__();
}


impl _NetBase.with_netmask.getter -> str {
    return self.network_address.__str__() + "/" + self.netmask.__str__();
}


impl _NetBase.with_hostmask.getter -> str {
    return self.network_address.__str__() + "/" + self.hostmask.__str__();
}


impl _NetBase.is_multicast.getter -> bool {
    return self.network_address.is_multicast and self.broadcast_address.is_multicast;
}


impl _NetBase.is_reserved.getter -> bool {
    return self.network_address.is_reserved and self.broadcast_address.is_reserved;
}


impl _NetBase.is_link_local.getter -> bool {
    return self.network_address.is_link_local and self.broadcast_address.is_link_local;
}


impl _NetBase.is_private.getter -> bool {
    if self.version == 4 {
        inside = False;
        for t in _v4_privates() {
            if _in_net32(self._net_lo, t[0], t[1])
                and _in_net32(self._bcast()[1], t[0], t[1]) {
                inside = True;
            }
        }
        if not inside {
            return False;
        }
        for t in _v4_private_exceptions() {
            if _in_net32(self._net_lo, t[0], t[1])
                or _in_net32(self._bcast()[1], t[0], t[1]) {
                return False;
            }
        }
        return True;
    }
    inside = False;
    for t in _v6_privates() {
        (bhi, blo) = self._bcast();
        if _in_net128(self._net_hi, self._net_lo, t[0], t[1], t[2])
            and _in_net128(bhi, blo, t[0], t[1], t[2]) {
            inside = True;
        }
    }
    if not inside {
        return False;
    }
    (bhi2, blo2) = self._bcast();
    for t in _v6_private_exceptions() {
        if _in_net128(self._net_hi, self._net_lo, t[0], t[1], t[2])
            or _in_net128(bhi2, blo2, t[0], t[1], t[2]) {
            return False;
        }
    }
    return True;
}


impl _NetBase.is_global.getter -> bool {
    if self.version == 4 {
        (bhi, blo) = self._bcast();
        if _in_net32(self._net_lo, 1681915904, 10) and _in_net32(blo, 1681915904, 10) {
            return False;
        }
    }
    return not self.is_private;
}


impl _NetBase.is_unspecified.getter -> bool {
    return self.network_address.is_unspecified
        and self.broadcast_address.is_unspecified;
}


impl _NetBase.is_loopback.getter -> bool {
    return self.network_address.is_loopback and self.broadcast_address.is_loopback;
}


impl _NetBase.is_site_local.getter -> bool {
    if self.version != 6 {
        return False;
    }
    return self.network_address.is_site_local and self.broadcast_address.is_site_local;
}


def _report_invalid_netmask(netmask: any) {
    raise NetmaskValueError(_repr_any(netmask) + " is not a valid netmask");
}


def _prefix_from_prefix_str(prefixlen_str: str, max_prefix: int) -> int {
    if not _is_digit_str(prefixlen_str) {
        _report_invalid_netmask(prefixlen_str);
    }
    prefixlen = int(prefixlen_str);
    if prefixlen < 0 or prefixlen > max_prefix {
        _report_invalid_netmask(prefixlen_str);
    }
    return prefixlen;
}


def _make_netmask_v4(arg: (str | int)) -> tuple[(u64, int)] {
    if isinstance(arg, int) {
        prefixlen = arg;
        if prefixlen < 0 or prefixlen > 32 {
            _report_invalid_netmask(arg);
        }
    } else {
        try {
            prefixlen = _prefix_from_prefix_str(arg, 32);
        } except NetmaskValueError {
            ip_int = 0;
            try {
                ip_int = _ip4_from_str(arg);
            } except AddressValueError {
                _report_invalid_netmask(arg);
            }
            try {
                prefixlen = _prefix_from_ip32(ip_int);
            } except ValueError {
                flipped = ip_int ^ 0xffffffff;
                try {
                    prefixlen = _prefix_from_ip32(flipped);
                } except ValueError {
                    _report_invalid_netmask(arg);
                }
            }
        }
    }
    return (_mask32(prefixlen), prefixlen);
}


def _make_netmask_v6(arg: (str | int)) -> tuple[(u64, u64, int)] {
    if isinstance(arg, int) {
        prefixlen = arg;
        if prefixlen < 0 or prefixlen > 128 {
            _report_invalid_netmask(arg);
        }
    } else {
        prefixlen = _prefix_from_prefix_str(arg, 128);
    }
    (mhi, mlo) = _netmask_from_prefix(prefixlen);
    return (mhi, mlo, prefixlen);
}


obj:pub IPv4Network(_NetBase) {
    def init(address: (str | int | bytes), strict: bool = True) {
        self.version = 4;
        net_lo = u64(0);
        mask_lo = u64(0);
        prefixlen = 32;
        if isinstance(address, int) {
            _check_int_address(address, 4);
            net_lo = u64(address);
            mask_lo = u64(0xffffffff);
        } elif isinstance(address, bytes) {
            _check_packed_address(address, 4, 4);
            net_lo = u64(int.from_bytes(address, "big"));
            mask_lo = u64(0xffffffff);
        } else {
            parts = _split_optional_netmask(address);
            net_lo = u64(_ip4_from_str(parts[0]));
            if len(parts) > 1 {
                (mask_lo, prefixlen) = _make_netmask_v4(parts[1]);
            } else {
                mask_lo = u64(0xffffffff);
            }
        }
        self._net_hi = u64(0);
        self._mask_hi = u64(0);
        self._prefixlen = prefixlen;
        if (net_lo & mask_lo) != net_lo {
            if strict {
                raise ValueError(
                    _ip4_to_str(int(net_lo))
                        + "/"
                        + str(prefixlen)
                        + " has host bits set"
                );
            }
            net_lo = net_lo & mask_lo;
        }
        self._net_lo = net_lo;
        self._mask_lo = mask_lo;
    }
}


obj:pub IPv6Network(_NetBase) {
    def init(address: (str | int | bytes), strict: bool = True) {
        self.version = 6;
        net_hi = u64(0);
        net_lo = u64(0);
        mask_hi = u64(0);
        mask_lo = u64(0);
        prefixlen = 128;
        if isinstance(address, int) {
            if address < 0 {
                raise AddressValueError(
                    str(address) + " (< 0) is not permitted as an IPv6 address"
                );
            }
            net_lo = u64(address);
            mask_hi = u64(0xffffffffffffffff);
            mask_lo = u64(0xffffffffffffffff);
        } elif isinstance(address, bytes) {
            _check_packed_address(address, 16, 6);
            net_hi = u64(int.from_bytes(address[0:8], "big"));
            net_lo = u64(int.from_bytes(address[8:16], "big"));
            mask_hi = u64(0xffffffffffffffff);
            mask_lo = u64(0xffffffffffffffff);
        } else {
            parts = _split_optional_netmask(address);
            (net_hi, net_lo, scope) = _ip6_from_str(parts[0]);
            if len(parts) > 1 {
                (mask_hi, mask_lo, prefixlen) = _make_netmask_v6(parts[1]);
            } else {
                mask_hi = u64(0xffffffffffffffff);
                mask_lo = u64(0xffffffffffffffff);
            }
        }
        self._prefixlen = prefixlen;
        if (net_hi & mask_hi) != net_hi or (net_lo & mask_lo) != net_lo {
            if strict {
                raise ValueError(
                    _ip6_to_str(net_hi, net_lo)
                        + "/"
                        + str(prefixlen)
                        + " has host bits set"
                );
            }
            net_hi = net_hi & mask_hi;
            net_lo = net_lo & mask_lo;
        }
        self._net_hi = net_hi;
        self._net_lo = net_lo;
        self._mask_hi = mask_hi;
        self._mask_lo = mask_lo;
    }
}


def:pub v4_int_to_packed(address: int) -> bytes {
    if address < 0 or address > 4294967295 {
        raise ValueError("Address negative or too large for IPv4");
    }
    return _v4_packed(address);
}


def:pub v6_int_to_packed(address: int) -> bytes {
    if address < 0 {
        raise ValueError("Address negative or too large for IPv6");
    }
    out = bytearray(16);
    x = address;
    for i in range(8) {
        out[15 - i] = x & 255;
        x = x >> 8;
    }
    return bytes(out);
}


def:pub ip_address(address: (str | int | bytes)) -> _AddrBase {
    try {
        return IPv4Address(address);
    } except AddressValueError {} except NetmaskValueError {}
    try {
        return IPv6Address(address);
    } except AddressValueError {} except NetmaskValueError {}
    raise ValueError(
        _repr_any(address) + " does not appear to be an IPv4 or IPv6 address"
    );
}


def:pub ip_network(address: (str | int | bytes), strict: bool = True) -> _NetBase {
    try {
        return IPv4Network(address, strict);
    } except AddressValueError {} except NetmaskValueError {}
    try {
        return IPv6Network(address, strict);
    } except AddressValueError {} except NetmaskValueError {}
    raise ValueError(
        _repr_any(address) + " does not appear to be an IPv4 or IPv6 network"
    );
}


def _blen128(hi: u64, lo: u64) -> int {
    if hi == u64(0) and lo == u64(0) {
        return 129;
    }
    if hi != u64(0) {
        return 64 + _blen(hi);
    }
    return _blen(lo);
}


def:pub summarize_address_range(
    first: _AddrBase, last: _AddrBase
) -> Iterator[_NetBase] {
    if first.version != last.version {
        raise TypeError(
            first.__str__() + " and " + last.__str__() + " are not of the same version"
        );
    }
    if _cmp128(first._hi, first._lo, last._hi, last._lo) > 0 {
        raise ValueError("last IP address must be greater than first");
    }
    ver = first.version;
    ip_bits = 32;
    if ver == 6 {
        ip_bits = 128;
    }
    (whi, wlo) = _shl1_128(ip_bits);
    f_hi = first._hi;
    f_lo = first._lo;
    l_hi = last._hi;
    l_lo = last._lo;
    while _cmp128(f_hi, f_lo, l_hi, l_lo) <= 0 {
        (d_hi, d_lo) = _sub128(l_hi, l_lo, f_hi, f_lo);
        (d_hi, d_lo) = _add128(d_hi, d_lo, u64(1));
        nbits = _count_rzb128(f_hi, f_lo, ip_bits);
        dbits = _blen128(d_hi, d_lo) - 1;
        if dbits < nbits {
            nbits = dbits;
        }
        yield _mknet(ver, f_hi, f_lo, ip_bits - nbits);
        (sh, sl) = _shl1_128(nbits);
        (f_hi, f_lo) = _add128(wrapping_add(f_hi, sh), f_lo, sl);
        if f_hi == whi and f_lo == wlo {
            break;
        }
    }
}
