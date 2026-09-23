"""Bundled native ``urllib.parse`` cross-backend equivalence fixture (#6978).

The sv entry drives CPython's real ``urllib.parse`` module. The na entry drives
the bundled ``na_stdlib/urllib/parse.jac`` module and must yield identical
scalar output. ES/JS opts out.

Native workarounds in the na lane:

- ``str()`` does not lower on ``str | None`` / ``int | None`` values, so
  optional components are routed through ``_os``/``_oi``.
- Tuple element types are lost across the module boundary (stubcat), so
  tuple-returning ``split*`` results are bound through annotated locals
  (``tt: tuple[((str | None), str)] = ...``) and their repr strings are
  assembled by hand. Local ``def`` helpers need native placement pins --
  unpinned they demote to Python and return 0 through the JIT bridge, and
  tuple-typed signatures cannot cross that boundary at all.
- ``urlunparse``/``urlunsplit`` take a union of result objects and
  ``list[str]`` natively (``any``-typed params lose element tags); the py lane
  also passes a list for parity. ``tuple`` component sequences are a native
  gap.
- ``urlencode`` natively accepts ``dict[str, str | list[str]]`` or
  ``list[list[str]]``. CPython also accepts pair-tuple sequences (and
  *requires* pairs to be tuples), but typed-tuple elements lose their tags
  through ``any``/union params natively, so tuple-pair ``urlencode`` is a
  native gap and is not exercised here.
"""

import urllib.parse as up;
import warnings;


def _rs(x: str) -> str {
    return "'" + x + "'";
}


def _ro(x: (str | None)) -> str {
    if isinstance(x, str) {
        return "'" + x + "'";
    }
    return "None";
}


def urlparse_py() -> dict[any, any] {
    warnings.simplefilter("ignore", DeprecationWarning);
    r = up.urlparse("http://user:pass@host.com:8080/path;params?q=1#frag");
    s = up.urlsplit("https://[2001:db8::1]:443/a/b?x#y");
    tt = up.splittype("http://h/p");
    hh = up.splithost("//h:8/p");
    uu = up.splituser("u:p@h");
    pp = up.splitpasswd("u:p");
    sp = up.splitport("h:80");
    sn = up.splitnport("h:80");
    sq = up.splitquery("/p?q");
    st = up.splittag("/p#t");
    sa = up.splitattr("/p;a;b");
    sv = up.splitvalue("a=v");
    qs = up.parse_qs("a=1&b=2&a=3");
    qsl = up.parse_qsl("a=1&b=2&a=3");
    qsl_blank = up.parse_qsl("a=1&&b=");
    qsl_keep = up.parse_qsl("a=1&&b=", keep_blank_values=True);
    qsl_semi = up.parse_qsl("a;b", separator=";");
    d = up.urldefrag("http://h/p?q#frag");
    e1 = "";
    try {
        tmp1 = up.urlparse("http://[10.0.0.1]/");
        h1 = tmp1.hostname;
    } except ValueError as ex {
        e1 = "ValueError:" + str(ex);
    }
    e2 = "";
    try {
        tmp2 = up.urlparse("http://h:99999/");
        p1 = tmp2.port;
    } except ValueError as ex {
        e2 = "ValueError:" + str(ex);
    }
    e3 = "";
    try {
        tmp3 = up.urlsplit("http://h:bad/");
        p2 = tmp3.port;
    } except ValueError {
        e3 = "ValueError";
    }
    return {
        "scheme": r.scheme,
        "netloc": r.netloc,
        "path": r.path,
        "params": r.params,
        "query": r.query,
        "fragment": r.fragment,
        "username": r.username,
        "password": r.password,
        "hostname": r.hostname,
        "port": str(r.port),
        "geturl": r.geturl(),
        "s_scheme": s.scheme,
        "s_netloc": s.netloc,
        "s_hostname": s.hostname,
        "s_port": str(s.port),
        "s_geturl": s.geturl(),
        "unparse_list": up.urlunparse(["http", "h.com", "/p", "pa", "q", "f"]),
        "unparse_res": up.urlunparse(r),
        "unsplit_list": up.urlunsplit(["http", "h.com", "/p", "q", "f"]),
        "unsplit_res": up.urlunsplit(s),
        "join_rel": up.urljoin("http://a.com/b/c/d", "e"),
        "join_abs": up.urljoin("http://a.com/b/c/d", "/e"),
        "join_up": up.urljoin("http://a.com/b/c/d", "../e"),
        "join_absurl": up.urljoin("http://a.com/b", "http://x.com/z"),
        "join_query": up.urljoin("http://a.com/b/c/d", "?q=2"),
        "join_frag": up.urljoin("http://a.com/b/c/d", "#f2"),
        "join_empty": up.urljoin("http://a.com/b/c/d", ""),
        "defrag_url": d.url,
        "defrag_frag": d.fragment,
        "defrag_geturl": d.geturl(),
        "quote": up.quote("abc def/~"),
        "quote_safe": up.quote("abc def", safe=""),
        "quote_utf8": up.quote("h\u00e9llo"),
        "quote_plus": up.quote_plus("a b+c"),
        "qfb": str(up.quote_from_bytes(b"a b!")),
        "unquote": up.unquote("a%20b%21"),
        "unquote_utf8": up.unquote("h%C3%A9llo"),
        "unquote_plus": up.unquote_plus("a+b%21"),
        "unquote_bad": up.unquote("%zz"),
        "unq_tb": str(up.unquote_to_bytes("a%20b%FF")),
        "qsl": str(qsl),
        "qsl_blank": str(qsl_blank),
        "qsl_keep": str(qsl_keep),
        "qsl_semi": str(qsl_semi),
        "qs_a": str(qs["a"]),
        "qs_b": str(qs["b"]),
        "enc_dict": up.urlencode({"a": "1", "b": "x y"}),
        "enc_doseq": up.urlencode({"a": ["1", "2"]}, doseq=True),
        "unwrap": up.unwrap("<URL:http://h/p>"),
        "splittype": str(tt),
        "splithost": str(hh),
        "splituser": str(uu),
        "splitpasswd": str(pp),
        "splitport": str(sp),
        "splitnport": str(sn),
        "splitquery": str(sq),
        "splittag": str(st),
        "splitattr": str(sa),
        "splitvalue": str(sv),
        "getitem": r[0] + "|" + r[5],
        "unquote_pct": up.urlsplit("http://h/%70ath").path,
        "err_ipv4_brackets": e1,
        "err_port_range": e2,
        "err_port_bad": e3,
        "rel_g": up.urljoin("http://a/b", "g:h"),
        "scheme_mailto": up.urlparse("mailto:x@y.z").scheme,
        "parse_empty": str(up.parse_qs(""))
    };
}


def urlparse_cl() -> dict[any, any] {
    return {};
}


# ---- native lane ----


def _os(x: (str | None)) -> str {
    if isinstance(x, str) {
        return x;
    }
    return "None";
}


def _oi(x: (int | None)) -> str {
    if isinstance(x, int) {
        return str(x);
    }
    return "None";
}


def urlparse_na() -> dict[str, any] {
    r = up.urlparse("http://user:pass@host.com:8080/path;params?q=1#frag");
    s = up.urlsplit("https://[2001:db8::1]:443/a/b?x#y");
    tt: tuple[((str | None), str)] = up.splittype("http://h/p");
    hh: tuple[((str | None), str)] = up.splithost("//h:8/p");
    uu: tuple[((str | None), str)] = up.splituser("u:p@h");
    pp: tuple[(str, (str | None))] = up.splitpasswd("u:p");
    sp: tuple[(str, (str | None))] = up.splitport("h:80");
    sn: tuple[(str, int)] = up.splitnport("h:80");
    sq: tuple[(str, (str | None))] = up.splitquery("/p?q");
    st: tuple[(str, (str | None))] = up.splittag("/p#t");
    sa: tuple[(str, list[str])] = up.splitattr("/p;a;b");
    sv: tuple[(str, (str | None))] = up.splitvalue("a=v");
    qsl: list[tuple[(str, str)]] = up.parse_qsl("a=1&b=2&a=3");
    qsl_blank: list[tuple[(str, str)]] = up.parse_qsl("a=1&&b=");
    qsl_keep: list[tuple[(str, str)]] = up.parse_qsl(
        "a=1&&b=", keep_blank_values=True
    );
    qsl_semi: list[tuple[(str, str)]] = up.parse_qsl("a;b", separator=";");
    qsl_parts: list[str] = [];
    for (k, v) in qsl {
        qsl_parts.append("(" + _rs(k) + ", " + _rs(v) + ")");
    }
    qsl_blank_parts: list[str] = [];
    for (k, v) in qsl_blank {
        qsl_blank_parts.append("(" + _rs(k) + ", " + _rs(v) + ")");
    }
    qsl_keep_parts: list[str] = [];
    for (k, v) in qsl_keep {
        qsl_keep_parts.append("(" + _rs(k) + ", " + _rs(v) + ")");
    }
    qsl_semi_parts: list[str] = [];
    for (k, v) in qsl_semi {
        qsl_semi_parts.append("(" + _rs(k) + ", " + _rs(v) + ")");
    }
    qs = up.parse_qs("a=1&b=2&a=3");
    d = up.urldefrag("http://h/p?q#frag");
    e1 = "";
    try {
        tmp1 = up.urlparse("http://[10.0.0.1]/");
        h1 = tmp1.hostname;
    } except ValueError as ex {
        e1 = "ValueError:" + str(ex);
    }
    e2 = "";
    try {
        tmp2 = up.urlparse("http://h:99999/");
        p1 = tmp2.port;
    } except ValueError as ex {
        e2 = "ValueError:" + str(ex);
    }
    e3 = "";
    try {
        tmp3 = up.urlsplit("http://h:bad/");
        p2 = tmp3.port;
    } except ValueError {
        e3 = "ValueError";
    }
    return {
        "scheme": r.scheme,
        "netloc": r.netloc,
        "path": r.path,
        "params": r.params,
        "query": r.query,
        "fragment": r.fragment,
        "username": _os(r.username),
        "password": _os(r.password),
        "hostname": _os(r.hostname),
        "port": _oi(r.port),
        "geturl": r.geturl(),
        "s_scheme": s.scheme,
        "s_netloc": s.netloc,
        "s_hostname": _os(s.hostname),
        "s_port": _oi(s.port),
        "s_geturl": s.geturl(),
        "unparse_list": up.urlunparse(["http", "h.com", "/p", "pa", "q", "f"]),
        "unparse_res": up.urlunparse(r),
        "unsplit_list": up.urlunsplit(["http", "h.com", "/p", "q", "f"]),
        "unsplit_res": up.urlunsplit(s),
        "join_rel": up.urljoin("http://a.com/b/c/d", "e"),
        "join_abs": up.urljoin("http://a.com/b/c/d", "/e"),
        "join_up": up.urljoin("http://a.com/b/c/d", "../e"),
        "join_absurl": up.urljoin("http://a.com/b", "http://x.com/z"),
        "join_query": up.urljoin("http://a.com/b/c/d", "?q=2"),
        "join_frag": up.urljoin("http://a.com/b/c/d", "#f2"),
        "join_empty": up.urljoin("http://a.com/b/c/d", ""),
        "defrag_url": d.url,
        "defrag_frag": _os(d.fragment),
        "defrag_geturl": d.geturl(),
        "quote": up.quote("abc def/~"),
        "quote_safe": up.quote("abc def", safe=""),
        "quote_utf8": up.quote("h\u00e9llo"),
        "quote_plus": up.quote_plus("a b+c"),
        "qfb": str(up.quote_from_bytes(b"a b!")),
        "unquote": up.unquote("a%20b%21"),
        "unquote_utf8": up.unquote("h%C3%A9llo"),
        "unquote_plus": up.unquote_plus("a+b%21"),
        "unquote_bad": up.unquote("%zz"),
        "unq_tb": str(up.unquote_to_bytes("a%20b%FF")),
        "qsl": "[" + ", ".join(qsl_parts) + "]",
        "qsl_blank": "[" + ", ".join(qsl_blank_parts) + "]",
        "qsl_keep": "[" + ", ".join(qsl_keep_parts) + "]",
        "qsl_semi": "[" + ", ".join(qsl_semi_parts) + "]",
        "qs_a": str(qs["a"]),
        "qs_b": str(qs["b"]),
        "enc_dict": up.urlencode({"a": "1", "b": "x y"}),
        "enc_doseq": up.urlencode({"a": ["1", "2"]}, doseq=True),
        "unwrap": up.unwrap("<URL:http://h/p>"),
        "splittype": "(" + _ro(tt[0]) + ", " + _rs(tt[1]) + ")",
        "splithost": "(" + _ro(hh[0]) + ", " + _rs(hh[1]) + ")",
        "splituser": "(" + _ro(uu[0]) + ", " + _rs(uu[1]) + ")",
        "splitpasswd": "(" + _rs(pp[0]) + ", " + _ro(pp[1]) + ")",
        "splitport": "(" + _rs(sp[0]) + ", " + _ro(sp[1]) + ")",
        "splitnport": "(" + _rs(sn[0]) + ", " + str(sn[1]) + ")",
        "splitquery": "(" + _rs(sq[0]) + ", " + _ro(sq[1]) + ")",
        "splittag": "(" + _rs(st[0]) + ", " + _ro(st[1]) + ")",
        "splitattr": "(" + _rs(sa[0]) + ", " + str(sa[1]) + ")",
        "splitvalue": "(" + _rs(sv[0]) + ", " + _ro(sv[1]) + ")",
        "getitem": r.__getitem__(0) + "|" + r.__getitem__(5),
        "unquote_pct": up.urlsplit("http://h/%70ath").path,
        "err_ipv4_brackets": e1,
        "err_port_range": e2,
        "err_port_bad": e3,
        "rel_g": up.urljoin("http://a/b", "g:h"),
        "scheme_mailto": up.urlparse("mailto:x@y.z").scheme,
        "parse_empty": str(up.parse_qs(""))
    };
}
