import ipaddress;

glob uses_relative: list[str] = [
         "",
         "ftp",
         "http",
         "gopher",
         "nntp",
         "imap",
         "wais",
         "file",
         "https",
         "shttp",
         "mms",
         "prospero",
         "rtsp",
         "rtsps",
         "rtspu",
         "svn",
         "tel",
         "wais",
         "ldap",
         "sftp",
         "svn+ssh",
         "git",
         "git+ssh",
         "smb",
         "ws",
         "wss",
         "itms-services"
     ],
     uses_netloc: list[str] = [
         "",
         "ftp",
         "http",
         "gopher",
         "nntp",
         "telnet",
         "imap",
         "wais",
         "file",
         "mms",
         "https",
         "shttp",
         "snews",
         "prospero",
         "rtsp",
         "rtsps",
         "rtspu",
         "rsync",
         "svn",
         "svn+ssh",
         "sftp",
         "nfs",
         "git",
         "git+ssh",
         "ws",
         "wss",
         "itms-services"
     ],
     uses_params: list[str] = [
         "",
         "ftp",
         "hdl",
         "prospero",
         "http",
         "imap",
         "https",
         "shttp",
         "rtsp",
         "rtsps",
         "rtspu",
         "sip",
         "sips",
         "mms",
         "sftp",
         "tel"
     ],
     non_hierarchical: list[str] = [
         "gopher",
         "hdl",
         "mailto",
         "news",
         "telnet",
         "wais",
         "imap",
         "snews",
         "sip",
         "sips"
     ],
     uses_query: list[str] = [
         "",
         "http",
         "wais",
         "imap",
         "https",
         "shttp",
         "mms",
         "gopher",
         "rtsp",
         "rtsps",
         "rtspu",
         "sip",
         "sips"
     ],
     uses_fragment: list[str] = [
         "",
         "ftp",
         "hdl",
         "http",
         "gopher",
         "news",
         "nntp",
         "wais",
         "https",
         "shttp",
         "snews",
         "file",
         "prospero"
     ],
     scheme_chars: str = "abcdefghijklmnopqrstuvwxyz"
     "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-.",
     _ALWAYS_SAFE: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
     "abcdefghijklmnopqrstuvwxyz0123456789_.-~",
     _HEXDIG: str = "0123456789ABCDEFabcdef",
     _HEXUP: str = "0123456789ABCDEF";


obj _Parts {
    has scheme: (str | None) = None,
        netloc: (str | None) = None,
        path: str = "",
        query: (str | None) = None,
        fragment: (str | None) = None;
}


obj:pub SplitResult {
    has scheme: str = "",
        netloc: str = "",
        path: str = "",
        query: str = "",
        fragment: str = "";

    has username: (str | None) { getter; }
    has password: (str | None) { getter; }
    has hostname: (str | None) { getter; }
    has port: (int | None) { getter; }

    def geturl -> str;
    def __getitem__(i: int) -> str;
}


obj:pub ParseResult {
    has scheme: str = "",
        netloc: str = "",
        path: str = "",
        params: str = "",
        query: str = "",
        fragment: str = "";

    has username: (str | None) { getter; }
    has password: (str | None) { getter; }
    has hostname: (str | None) { getter; }
    has port: (int | None) { getter; }

    def geturl -> str;
    def __getitem__(i: int) -> str;
}


obj:pub DefragResult {
    has url: str = "",
        fragment: str = "";

    def geturl -> str;
    def __getitem__(i: int) -> str;
}


def _lstrip_c0(url: str) -> str {
    i = 0;
    while i < len(url) and ord(url[i]) <= 0x20 {
        i += 1;
    }
    return url[i:];
}


def _strip_c0(url: str) -> str {
    i = 0;
    j = len(url);
    while i < j and ord(url[i]) <= 0x20 {
        i += 1;
    }
    while j > i and ord(url[j - 1]) <= 0x20 {
        j -= 1;
    }
    return url[i:j];
}


def _remove_unsafe(url: str) -> str {
    return url.replace("\t", "").replace("\r", "").replace("\n", "");
}


def _partition(s: str, sep: str) -> tuple[(str, str, str)] {
    i = s.find(sep);
    if i < 0 {
        return (s, "", "");
    }
    return (s[:i], sep, s[i + len(sep):]);
}


def _rpartition(s: str, sep: str) -> tuple[(str, str, str)] {
    i = s.rfind(sep);
    if i < 0 {
        return ("", "", s);
    }
    return (s[:i], sep, s[i + len(sep):]);
}


def _splitnetloc(url: str, start: int) -> tuple[(str, str)] {
    delim = len(url);
    for c in ["/", "?", "#"] {
        wdelim = url.find(c, start);
        if wdelim >= 0 and wdelim < delim {
            delim = wdelim;
        }
    }
    return (url[start:delim], url[delim:]);
}


def _splitparams(url: str, allow_none: bool) -> tuple[(str, (str | None))] {
    if "/" in url {
        i = url.find(";", url.rfind("/"));
        if i < 0 {
            if allow_none {
                return (url, None);
            }
            return (url, "");
        }
    } else {
        i = url.find(";");
        if i < 0 {
            if allow_none {
                return (url, None);
            }
            return (url, "");
        }
    }
    return (url[:i], url[i + 1:]);
}


def _check_bracketed_host(hostname: str) {
    if len(hostname) > 0 and (hostname[0] == "v" or hostname[0] == "V") {
        dot = hostname.find(".");
        ok = dot > 1 and dot < len(hostname) - 1;
        if ok {
            for i in range(1, dot) {
                if hostname[i] not in _HEXDIG {
                    ok = False;
                }
            }
        }
        if not ok {
            raise ValueError("IPvFuture address is invalid");
        }
        return;
    }
    ip = ipaddress.ip_address(hostname);
    if ip.version == 4 {
        raise ValueError("An IPv4 address cannot be in brackets");
    }
}


def _check_bracketed_netloc(netloc: str) {
    (u, h, hostname_and_port) = _rpartition(netloc, "@");
    (before_bracket, have_open_br, bracketed) = _partition(hostname_and_port, "[");
    if len(have_open_br) > 0 {
        if len(before_bracket) > 0 {
            raise ValueError("Invalid IPv6 URL");
        }
        (hostname, c, port) = _partition(bracketed, "]");
        if len(port) > 0 and not port.startswith(":") {
            raise ValueError("Invalid IPv6 URL");
        }
    } else {
        (hostname, c2, port2) = _partition(hostname_and_port, ":");
    }
    _check_bracketed_host(hostname);
}


def _urlsplit(url: str, scheme: (str | None), allow_fragments: bool) -> _Parts {
    url = _lstrip_c0(url);
    url = _remove_unsafe(url);
    sch: (str | None) = None;
    if isinstance(scheme, str) {
        sch = _strip_c0(scheme);
        sch = _remove_unsafe(sch);
    }
    netloc: (str | None) = None;
    query: (str | None) = None;
    fragment: (str | None) = None;
    i = url.find(":");
    if i > 0 and ord(url[0]) < 128 and url[0].isalpha() {
        bad = False;
        for j in range(i) {
            if url[j] not in scheme_chars {
                bad = True;
            }
        }
        if not bad {
            sch = url[:i].lower();
            url = url[i + 1:];
        }
    }
    if url[:2] == "//" {
        (nl, rest) = _splitnetloc(url, 2);
        netloc = nl;
        url = rest;
        if ("[" in nl and "]" not in nl) or ("]" in nl and "[" not in nl) {
            raise ValueError("Invalid IPv6 URL");
        }
        if "[" in nl and "]" in nl {
            _check_bracketed_netloc(nl);
        }
    }
    if allow_fragments {
        fi = url.find("#");
        if fi >= 0 {
            fragment = url[fi + 1:];
            url = url[:fi];
        }
    }
    qi = url.find("?");
    if qi >= 0 {
        query = url[qi + 1:];
        url = url[:qi];
    }
    return _Parts(scheme=sch, netloc=netloc, path=url, query=query, fragment=fragment);
}


def _urlunsplit(
    scheme: (str | None),
    netloc: (str | None),
    url: str,
    query: (str | None),
    fragment: (str | None)
) -> str {
    if isinstance(netloc, str) {
        if len(url) > 0 and url[:1] != "/" {
            url = "/" + url;
        }
        url = "//" + netloc + url;
    } elif url[:2] == "//" {
        url = "//" + url;
    }
    if isinstance(scheme, str) and len(scheme) > 0 {
        url = scheme + ":" + url;
    }
    if isinstance(query, str) {
        url = url + "?" + query;
    }
    if isinstance(fragment, str) {
        url = url + "#" + fragment;
    }
    return url;
}


def:pub urlsplit(
    url: str, scheme: str = "", allow_fragments: bool = True
) -> SplitResult {
    p = _urlsplit(url, scheme, allow_fragments);
    return SplitResult(
        scheme=p.scheme if isinstance(p.scheme, str) else "",
        netloc=p.netloc if isinstance(p.netloc, str) else "",
        path=p.path,
        query=p.query if isinstance(p.query, str) else "",
        fragment=p.fragment if isinstance(p.fragment, str) else ""
    );
}


def:pub urlparse(
    url: str, scheme: str = "", allow_fragments: bool = True
) -> ParseResult {
    p = _urlsplit(url, scheme, allow_fragments);
    params: (str | None) = None;
    sch = p.scheme if isinstance(p.scheme, str) else "";
    if sch in uses_params and ";" in p.path {
        (url2, params) = _splitparams(p.path, True);
    } else {
        url2 = p.path;
    }
    return ParseResult(
        scheme=sch,
        netloc=p.netloc if isinstance(p.netloc, str) else "",
        path=url2,
        params=params if isinstance(params, str) else "",
        query=p.query if isinstance(p.query, str) else "",
        fragment=p.fragment if isinstance(p.fragment, str) else ""
    );
}


def _components(
    c: (ParseResult | SplitResult | DefragResult | list[str])
) -> list[str] {
    if isinstance(c, ParseResult) {
        return [c.scheme, c.netloc, c.path, c.params, c.query, c.fragment];
    }
    if isinstance(c, SplitResult) {
        return [c.scheme, c.netloc, c.path, c.query, c.fragment];
    }
    if isinstance(c, DefragResult) {
        return [c.url, c.fragment];
    }
    return c;
}


def:pub urlunparse(
    components: (ParseResult | SplitResult | DefragResult | list[str])
) -> str {
    c = _components(components);
    if len(c) != 6 {
        raise ValueError("urlunparse() needs a 6-component sequence");
    }
    netloc: (str | None) = c[1];
    if len(c[1]) == 0 {
        if len(c[0]) > 0
            and c[0] in uses_netloc
            and (len(c[2]) == 0 or c[2][:1] == "/") {
            netloc = "";
        } else {
            netloc = None;
        }
    }
    url = c[2];
    if len(c[3]) > 0 {
        url = url + ";" + c[3];
    }
    query: (str | None) = c[4];
    fragment: (str | None) = c[5];
    return _urlunsplit(c[0] if len(c[0]) > 0 else None, netloc, url, query, fragment);
}


def:pub urlunsplit(
    components: (ParseResult | SplitResult | DefragResult | list[str])
) -> str {
    c = _components(components);
    if len(c) == 6 {
        if len(c[3]) > 0 {
            c[2] = c[2] + ";" + c[3];
        }
        c = [c[0], c[1], c[2], c[4], c[5]];
    }
    if len(c) != 5 {
        raise ValueError("urlunsplit() needs a 5-component sequence");
    }
    netloc: (str | None) = c[1];
    if len(c[1]) == 0 {
        if len(c[0]) > 0
            and c[0] in uses_netloc
            and (len(c[2]) == 0 or c[2][:1] == "/") {
            netloc = "";
        } else {
            netloc = None;
        }
    }
    query: (str | None) = c[3];
    fragment: (str | None) = c[4];
    return _urlunsplit(c[0] if len(c[0]) > 0 else None, netloc, c[2], query, fragment);
}


def:pub urljoin(base: str, url: str, allow_fragments: bool = True) -> str {
    if len(base) == 0 {
        return url;
    }
    if len(url) == 0 {
        return base;
    }
    b = _urlsplit(base, None, allow_fragments);
    u = _urlsplit(url, None, allow_fragments);
    bscheme = b.scheme;
    scheme = u.scheme;
    if not isinstance(scheme, str) {
        scheme = bscheme;
    }
    if scheme != bscheme
        or (
            isinstance(scheme, str) and len(scheme) > 0 and scheme not in uses_relative
        ) {
        return url;
    }
    netloc = u.netloc;
    if (not isinstance(scheme, str) or len(scheme) == 0 or scheme in uses_netloc) {
        if isinstance(netloc, str) and len(netloc) > 0 {
            return _urlunsplit(scheme, netloc, u.path, u.query, u.fragment);
        }
        netloc = b.netloc;
    }
    path = u.path;
    query = u.query;
    fragment = u.fragment;
    if len(path) == 0 {
        path = b.path;
        if not isinstance(query, str) {
            query = b.query;
            if not isinstance(fragment, str) {
                fragment = b.fragment;
            }
        }
        return _urlunsplit(scheme, netloc, path, query, fragment);
    }
    base_parts = b.path.split("/");
    if base_parts[len(base_parts) - 1] != "" {
        base_parts = base_parts[:len(base_parts) - 1];
    }
    segments: list[str] = [];
    if path[:1] == "/" {
        segments = path.split("/");
    } else {
        segments = base_parts + path.split("/");
        filtered: list[str] = [];
        for k in range(len(segments)) {
            if k == 0 or k == len(segments) - 1 or len(segments[k]) > 0 {
                filtered.append(segments[k]);
            }
        }
        segments = filtered;
    }
    resolved: list[str] = [];
    for seg in segments {
        if seg == ".." {
            if len(resolved) > 0 {
                resolved = resolved[:len(resolved) - 1];
            }
        } elif seg != "." {
            resolved.append(seg);
        }
    }
    last = segments[len(segments) - 1];
    if last == "." or last == ".." {
        resolved.append("");
    }
    rpath = "/".join(resolved);
    if len(rpath) == 0 {
        rpath = "/";
    }
    return _urlunsplit(scheme, netloc, rpath, query, fragment);
}


def:pub urldefrag(url: str) -> DefragResult {
    if "#" in url {
        p = _urlsplit(url, None, True);
        defrag = _urlunsplit(p.scheme, p.netloc, p.path, p.query, None);
        frag = p.fragment if isinstance(p.fragment, str) else "";
        return DefragResult(url=defrag, fragment=frag);
    }
    return DefragResult(url=url, fragment="");
}


def _hexval(a: str, b: str) -> int {
    ai = _HEXDIG.find(a);
    bi = _HEXDIG.find(b);
    if ai < 0 or bi < 0 {
        return -1;
    }
    return (ai % 16) * 16 + (bi % 16);
}


def _hexbyte(b: int) -> str {
    return "%" + _HEXUP[b // 16] + _HEXUP[b % 16];
}


def:pub unquote_to_bytes(string: any) -> bytes {
    if isinstance(string, str) {
        if len(string) == 0 {
            return b"";
        }
        bs: list[int] = [];
        i = 0;
        n = len(string);
        while i < n {
            if string[i] == "%" and i + 2 < n {
                h = _hexval(string[i + 1], string[i + 2]);
                if h >= 0 {
                    bs.append(h);
                    i += 3;
                    continue;
                }
            }
            bs.append(ord(string[i]));
            i += 1;
        }
        return bytes(bs);
    }
    if isinstance(string, bytes) {
        return _unquote_bytes(string);
    }
    raise TypeError("unquote_to_bytes() expected str or bytes");
}


def _unquote_bytes(data: bytes) -> bytes {
    bs: list[int] = [];
    i = 0;
    n = len(data);
    while i < n {
        if data[i] == 37 and i + 2 < n {
            h = _hexval(chr(data[i + 1]), chr(data[i + 2]));
            if h >= 0 {
                bs.append(h);
                i += 3;
                continue;
            }
        }
        bs.append(data[i]);
        i += 1;
    }
    return bytes(bs);
}


def _utf8_decode(bs: list[int], errors: str) -> str {
    out = "";
    i = 0;
    n = len(bs);
    while i < n {
        b = bs[i];
        if b < 128 {
            out += chr(b);
            i += 1;
            continue;
        }
        need = 0;
        cp = 0;
        if b >= 0xC2 and b <= 0xDF {
            need = 1;
            cp = b & 0x1F;
        } elif b >= 0xE0 and b <= 0xEF {
            need = 2;
            cp = b & 0x0F;
        } elif b >= 0xF0 and b <= 0xF4 {
            need = 3;
            cp = b & 0x07;
        } else {
            if errors == "strict" {
                raise ValueError("invalid start byte in utf-8");
            }
            if errors != "ignore" {
                out += chr(0xFFFD);
            }
            i += 1;
            continue;
        }
        ok = i + need < n;
        if ok {
            for k in range(1, need + 1) {
                cb = bs[i + k];
                if cb < 0x80 or cb > 0xBF {
                    ok = False;
                }
            }
        }
        if not ok {
            if errors == "strict" {
                raise ValueError("invalid continuation byte in utf-8");
            }
            if errors != "ignore" {
                out += chr(0xFFFD);
            }
            i += 1;
            continue;
        }
        for k in range(1, need + 1) {
            cp = (cp << 6) | (bs[i + k] & 0x3F);
        }
        if cp > 0x10FFFF
            or (cp >= 0xD800 and cp <= 0xDFFF)
            or (need == 1 and cp < 0x80)
            or (need == 2 and cp < 0x800)
            or (need == 3 and cp < 0x10000) {
            if errors == "strict" {
                raise ValueError("invalid utf-8 codepoint");
            }
            if errors != "ignore" {
                out += chr(0xFFFD);
            } else {
                out += chr(cp);
            }
        } else {
            out += chr(cp);
        }
        i += need + 1;
    }
    return out;
}


def:pub unquote(string: str, encoding: str = "utf-8", errors: str = "replace") -> str {
    if "%" not in string {
        return string;
    }
    bs: list[int] = [];
    i = 0;
    n = len(string);
    while i < n {
        if string[i] == "%" and i + 2 < n {
            h = _hexval(string[i + 1], string[i + 2]);
            if h >= 0 {
                bs.append(h);
                i += 3;
                continue;
            }
        }
        bs.append(ord(string[i]));
        i += 1;
    }
    return _utf8_decode(bs, errors);
}


def:pub unquote_plus(
    string: str, encoding: str = "utf-8", errors: str = "replace"
) -> str {
    return unquote(string.replace("+", " "), encoding, errors);
}


def _is_safe_byte(b: int, safe: str) -> bool {
    if b >= 128 {
        return False;
    }
    c = chr(b);
    return c in _ALWAYS_SAFE or c in safe;
}


def:pub quote(
    string: any,
    safe: str = "/",
    encoding: (str | None) = None,
    errors: (str | None) = None
) -> str {
    if isinstance(string, bytes) {
        if isinstance(encoding, str) {
            raise TypeError("quote() doesn't support 'encoding' for bytes");
        }
        if isinstance(errors, str) {
            raise TypeError("quote() doesn't support 'errors' for bytes");
        }
        return quote_from_bytes(string, safe);
    }
    if not isinstance(string, str) {
        raise TypeError("quote() expected str or bytes");
    }
    if len(string) == 0 {
        return string;
    }
    if isinstance(encoding, str) and encoding != "utf-8" {
        raise ValueError("quote() only supports utf-8 encoding");
    }
    out = "";
    i = 0;
    n = len(string);
    while i < n {
        b = ord(string[i]);
        if _is_safe_byte(b, safe) {
            out += string[i];
        } else {
            out += _hexbyte(b);
        }
        i += 1;
    }
    return out;
}


def:pub quote_from_bytes(bs: bytes, safe: str = "/") -> str {
    if not isinstance(bs, bytes) {
        raise TypeError("quote_from_bytes() expected bytes");
    }
    out = "";
    for i in range(len(bs)) {
        b = bs[i];
        if _is_safe_byte(b, safe) {
            out += chr(b);
        } else {
            out += _hexbyte(b);
        }
    }
    return out;
}


def:pub quote_plus(
    string: any,
    safe: str = "",
    encoding: (str | None) = None,
    errors: (str | None) = None
) -> str {
    quoted = quote(string, safe + " ", encoding, errors);
    return quoted.replace(" ", "+");
}


def:pub parse_qsl(
    qs: str,
    keep_blank_values: bool = False,
    strict_parsing: bool = False,
    encoding: str = "utf-8",
    errors: str = "replace",
    max_num_fields: (int | None) = None,
    separator: str = "&"
) -> list[tuple[(str, str)]] {
    if len(qs) == 0 {
        return [];
    }
    if isinstance(max_num_fields, int) {
        num_fields = 1 + qs.count(separator);
        if max_num_fields < num_fields {
            raise ValueError("Max number of fields exceeded");
        }
    }
    r: list[tuple[(str, str)]] = [];
    for name_value in qs.split(separator) {
        if len(name_value) > 0 or strict_parsing {
            (name, has_eq, value) = _partition(name_value, "=");
            if len(has_eq) == 0 and strict_parsing {
                raise ValueError("bad query field: " + name_value);
            }
            if len(value) > 0 or keep_blank_values {
                r.append(
                    (
                        unquote_plus(name, encoding, errors),
                        unquote_plus(value, encoding, errors)
                    )
                );
            }
        }
    }
    return r;
}


def:pub parse_qs(
    qs: str,
    keep_blank_values: bool = False,
    strict_parsing: bool = False,
    encoding: str = "utf-8",
    errors: str = "replace",
    max_num_fields: (int | None) = None,
    separator: str = "&"
) -> dict[str, list[str]] {
    parsed: dict[str, list[str]] = {};
    pairs = parse_qsl(
        qs,
        keep_blank_values,
        strict_parsing,
        encoding,
        errors,
        max_num_fields,
        separator
    );
    for (name, value) in pairs {
        if name in parsed {
            parsed[name].append(value);
        } else {
            parsed[name] = [value];
        }
    }
    return parsed;
}


def _enc_one(
    l: list[str],
    k: str,
    v: (str | list[str]),
    doseq: bool,
    safe: str,
    encoding: (str | None),
    errors: (str | None)
) {
    ks = quote_plus(k, safe, encoding, errors);
    if doseq and isinstance(v, list) {
        for elt in v {
            l.append(ks + "=" + quote_plus(elt, safe, encoding, errors));
        }
    } elif isinstance(v, str) {
        l.append(ks + "=" + quote_plus(v, safe, encoding, errors));
    } elif isinstance(v, list) {
        l.append(ks + "=" + quote_plus(str(v), safe, encoding, errors));
    }
}


def:pub urlencode(
    query: (dict[str, (str | list[str])] | list[list[str]]),
    doseq: bool = False,
    safe: str = "",
    encoding: (str | None) = None,
    errors: (str | None) = None
) -> str {
    l: list[str] = [];
    if isinstance(query, dict) {
        for (k, v) in query.items() {
            _enc_one(l, k, v, doseq, safe, encoding, errors);
        }
    } else {
        for pair in query {
            if len(pair) != 2 {
                raise TypeError("not a valid non-string sequence or mapping object");
            }
            _enc_one(l, pair[0], pair[1], doseq, safe, encoding, errors);
        }
    }
    return "&".join(l);
}


def:pub unwrap(url: str) -> str {
    url = url.strip();
    if url[:1] == "<" and url[len(url) - 1:] == ">" {
        url = url[1:len(url) - 1].strip();
    }
    if url[:4] == "URL:" {
        url = url[4:].strip();
    }
    return url;
}


def:pub splittype(url: str) -> tuple[((str | None), str)] {
    i = url.find(":");
    if i > 0 {
        for j in range(i) {
            if url[j] == "/" {
                return (None, url);
            }
        }
        return (url[:i].lower(), url[i + 1:]);
    }
    return (None, url);
}


def:pub splithost(url: str) -> tuple[((str | None), str)] {
    if url[:2] != "//" {
        return (None, url);
    }
    i = 2;
    n = len(url);
    while i < n and url[i] != "/" and url[i] != "#" and url[i] != "?" {
        i += 1;
    }
    host_port = url[2:i];
    path = url[i:];
    if len(path) > 0 and path[0] != "/" {
        path = "/" + path;
    }
    return (host_port, path);
}


def:pub splituser(host: str) -> tuple[((str | None), str)] {
    (user, delim, h) = _rpartition(host, "@");
    if len(delim) == 0 {
        return (None, h);
    }
    return (user, h);
}


def:pub splitpasswd(user: str) -> tuple[(str, (str | None))] {
    (u, delim, passwd) = _partition(user, ":");
    if len(delim) == 0 {
        return (u, None);
    }
    return (u, passwd);
}


def:pub splitport(host: str) -> tuple[(str, (str | None))] {
    i = host.rfind(":");
    if i < 0 {
        return (host, None);
    }
    port = host[i + 1:];
    ok = len(port) > 0;
    for j in range(len(port)) {
        if not port[j].isdigit() or ord(port[j]) >= 128 {
            ok = False;
        }
    }
    if ok {
        return (host[:i], port);
    }
    return (host, None);
}


def:pub splitnport(host: str, defport: int = -1) -> tuple[(str, int)] {
    (h, delim, port) = _rpartition(host, ":");
    if len(delim) == 0 {
        return (port, defport);
    }
    if len(port) == 0 {
        return (h, defport);
    }
    ok = True;
    for j in range(len(port)) {
        if not port[j].isdigit() or ord(port[j]) >= 128 {
            ok = False;
        }
    }
    if ok {
        return (h, int(port));
    }
    return (h, -1);
}


def:pub splitquery(url: str) -> tuple[(str, (str | None))] {
    (path, delim, query) = _rpartition(url, "?");
    if len(delim) > 0 {
        return (path, query);
    }
    return (url, None);
}


def:pub splittag(url: str) -> tuple[(str, (str | None))] {
    (path, delim, tag) = _rpartition(url, "#");
    if len(delim) > 0 {
        return (path, tag);
    }
    return (url, None);
}


def:pub splitattr(url: str) -> tuple[(str, list[str])] {
    words = url.split(";");
    return (words[0], words[1:]);
}


def:pub splitvalue(attr: str) -> tuple[(str, (str | None))] {
    (a, delim, value) = _partition(attr, "=");
    if len(delim) == 0 {
        return (a, None);
    }
    return (a, value);
}


def _userinfo(netloc: str) -> tuple[((str | None), (str | None))] {
    (userinfo, have_info, hostinfo) = _rpartition(netloc, "@");
    if len(have_info) > 0 {
        (username, have_password, password) = _partition(userinfo, ":");
        if len(have_password) == 0 {
            return (username, None);
        }
        return (username, password);
    }
    return (None, None);
}


def _hostinfo(netloc: str) -> tuple[((str | None), (str | None))] {
    (u, h, hostinfo) = _rpartition(netloc, "@");
    (x, have_open_br, bracketed) = _partition(hostinfo, "[");
    hostname = "";
    port: (str | None) = None;
    if len(have_open_br) > 0 {
        (hostname, b, rest) = _partition(bracketed, "]");
        (x2, c, port2) = _partition(rest, ":");
        if len(port2) > 0 {
            port = port2;
        }
    } else {
        (hostname, c3, port3) = _partition(hostinfo, ":");
        if len(port3) > 0 {
            port = port3;
        }
    }
    return (hostname, port);
}


def _port_of(port: (str | None)) -> (int | None) {
    if not isinstance(port, str) {
        return None;
    }
    ok = len(port) > 0;
    for j in range(len(port)) {
        if not port[j].isdigit() or ord(port[j]) >= 128 {
            ok = False;
        }
    }
    if not ok {
        raise ValueError("Port could not be cast to integer value as '" + port + "'");
    }
    p = int(port);
    if p < 0 or p > 65535 {
        raise ValueError("Port out of range 0-65535");
    }
    return p;
}


def _hostname_of(netloc: str) -> (str | None) {
    (hostname, port) = _hostinfo(netloc);
    if not isinstance(hostname, str) or len(hostname) == 0 {
        return None;
    }
    (hname, percent, zone) = _partition(hostname, "%");
    return hname.lower() + percent + zone;
}


impl SplitResult.username.getter -> (str | None) {
    (u, p) = _userinfo(self.netloc);
    return u;
}

impl SplitResult.password.getter -> (str | None) {
    (u, p) = _userinfo(self.netloc);
    return p;
}

impl SplitResult.hostname.getter -> (str | None) {
    return _hostname_of(self.netloc);
}

impl SplitResult.port.getter -> (int | None) {
    (h, p) = _hostinfo(self.netloc);
    return _port_of(p);
}

impl SplitResult.geturl -> str {
    return urlunsplit(self);
}

impl SplitResult.__getitem__(i: int) -> str {
    if i == 0 {
        return self.scheme;
    }
    if i == 1 {
        return self.netloc;
    }
    if i == 2 {
        return self.path;
    }
    if i == 3 {
        return self.query;
    }
    if i == 4 {
        return self.fragment;
    }
    raise IndexError("index out of range");
}


impl ParseResult.username.getter -> (str | None) {
    (u, p) = _userinfo(self.netloc);
    return u;
}

impl ParseResult.password.getter -> (str | None) {
    (u, p) = _userinfo(self.netloc);
    return p;
}

impl ParseResult.hostname.getter -> (str | None) {
    return _hostname_of(self.netloc);
}

impl ParseResult.port.getter -> (int | None) {
    (h, p) = _hostinfo(self.netloc);
    return _port_of(p);
}

impl ParseResult.geturl -> str {
    return urlunparse(self);
}

impl ParseResult.__getitem__(i: int) -> str {
    if i == 0 {
        return self.scheme;
    }
    if i == 1 {
        return self.netloc;
    }
    if i == 2 {
        return self.path;
    }
    if i == 3 {
        return self.params;
    }
    if i == 4 {
        return self.query;
    }
    if i == 5 {
        return self.fragment;
    }
    raise IndexError("index out of range");
}


impl DefragResult.geturl -> str {
    if len(self.fragment) > 0 {
        return self.url + "#" + self.fragment;
    }
    return self.url;
}

impl DefragResult.__getitem__(i: int) -> str {
    if i == 0 {
        return self.url;
    }
    if i == 1 {
        return self.fragment;
    }
    raise IndexError("index out of range");
}
