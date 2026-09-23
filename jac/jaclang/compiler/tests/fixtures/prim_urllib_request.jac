"""Bundled native ``urllib.request`` cross-backend equivalence fixture.

The sv entry drives CPython's real ``urllib.request``; the na entry drives
the bundled ``na_stdlib/urllib/request.jac``. ES/JS opts out.

Coverage is the pure/local surface: ``Request`` getters and headers,
``build_opener``, ``data:`` URL opens (no network), ``pathname2url`` /
``url2pathname``, ``parse_http_list`` / ``parse_keqv_list``, ``request_host``,
``ProxyHandler`` + explicit-dict ``proxy_bypass_environment``, and the
password managers (``find_user_password`` incl. default-realm fallback and
sub-URI matching).

Native divergences accounted for:

- na ``find_user_password`` returns ``(None, None)`` on a miss where CPython
  returns ``None`` (the return type is a fixed tuple), so both lanes emit a
  normalized ``"u|p"`` / ``"none"`` string.
- The default realm key is ``None`` in CPython and ``""`` natively (dict keys
  are typed ``str``); the lookup result is identical.
- na ``Request.data`` is ``any``; its length is read through an
  ``isinstance``-narrowed ``bytes``.
- ``resp.read()`` is ``bytes | str`` natively; narrowed before decode.
"""

import urllib.request as ureq;


def _fup_s(fup: any) -> str {
    if fup == None {
        return "none";
    }
    return fup[0] + "|" + fup[1];
}


def urlreq_py() -> dict[any, any] {
    r = ureq.Request("http://example.com/path?q=1#frag");
    r2 = ureq.Request("http://ex.com/p", data=b"abc");
    r3 = ureq.Request("http://ex.com/p", method="PUT");
    r.add_header("X-Test", "yes");
    mgr = ureq.HTTPPasswordMgr();
    mgr.add_password("realm1", "http://ex.com/x", "u1", "p1");
    mgr.add_password("realm1", ["http://ex.com:80/y", "http://ex.com/z"], "u2", "p2");
    mgrd = ureq.HTTPPasswordMgrWithDefaultRealm();
    mgrd.add_password(None, "http://ex.com/", "u3", "p3");
    ph = ureq.ProxyHandler({"http": "http://p:8080", "no": "ex.com,sub.ex.com"});
    resp = ureq.urlopen("data:,hello%20world");
    resp2 = ureq.urlopen("data:text/plain;base64,aGk=");
    op = ureq.build_opener();
    return {
        "m_get": r.get_method(),
        "m_post": r2.get_method(),
        "m_put": r3.get_method(),
        "type": r.type,
        "host": r.host,
        "selector": r.selector,
        "full_url": r.full_url,
        "frag": r.fragment,
        "has_h": r.has_header("X-test"),
        "has_h2": r.has_header("nope"),
        "dlen": len(r2.data),
        "rh": ureq.request_host(r),
        "p2u": ureq.pathname2url("/tmp/a b"),
        "p2u_s": ureq.pathname2url("/tmp/a b", add_scheme=True),
        "u2p": ureq.url2pathname("/tmp/a%20b"),
        "phl": ureq.parse_http_list("a, \"b,c\", d"),
        "pkl": ureq.parse_keqv_list(["k=v", "x=\"y z\""]),
        "fup": _fup_s(mgr.find_user_password("realm1", "http://ex.com/x/deep")),
        "fup_dp": _fup_s(mgr.find_user_password("realm1", "http://ex.com/y")),
        "fup_miss": _fup_s(mgr.find_user_password("nope", "http://ex.com/x")),
        "fup_d": _fup_s(mgrd.find_user_password("zzz", "http://ex.com/a/b")),
        "proxies": ph.proxies,
        "pb1": ureq.proxy_bypass_environment("www.ex.com", ph.proxies),
        "pb2": ureq.proxy_bypass_environment("other.com", ph.proxies),
        "pb3": ureq.proxy_bypass_environment("ex.com", ph.proxies),
        "op": 1 if op is not None else 0,
        "data_read": resp.read().decode(),
        "data_b64": resp2.read().decode()
    };
}


def urlreq_cl() -> dict[any, any] {
    return {};
}


# ---- native lane ----

import from urllib.response { addinfourl }
import from urllib.request {
    HTTPPasswordMgr,
    HTTPPasswordMgrWithDefaultRealm,
    ProxyHandler,
    Request,
    build_opener,
    parse_http_list,
    parse_keqv_list,
    pathname2url,
    proxy_bypass_environment,
    request_host,
    url2pathname,
    urlopen
}


def _fup_na(fup: tuple[((str | None), (str | None))]) -> str {
    a = fup[0];
    if a == None {
        return "none";
    }
    s1: str = a;
    b = fup[1];
    s2: str = b;
    return s1 + "|" + s2;
}


def urlreq_na() -> dict[str, any] {
    r = Request("http://example.com/path?q=1#frag");
    r2 = Request("http://ex.com/p", b"abc");
    r3 = Request("http://ex.com/p", method="PUT");
    r.add_header("X-Test", "yes");
    mgr = HTTPPasswordMgr();
    mgr.add_password("realm1", "http://ex.com/x", "u1", "p1");
    mgr.add_password("realm1", ["http://ex.com:80/y", "http://ex.com/z"], "u2", "p2");
    mgrd = HTTPPasswordMgrWithDefaultRealm();
    mgrd.add_password("", "http://ex.com/", "u3", "p3");
    ph = ProxyHandler({"http": "http://p:8080", "no": "ex.com,sub.ex.com"});
    resp0 = urlopen("data:,hello%20world");
    resp: addinfourl = resp0;
    resp02 = urlopen("data:text/plain;base64,aGk=");
    resp2: addinfourl = resp02;
    op = build_opener();
    dlen = 0;
    d = r2.data;
    if isinstance(d, bytes) {
        db: bytes = d;
        dlen = len(db);
    }
    raw = resp.read();
    data_read = "";
    if isinstance(raw, bytes) {
        rb: bytes = raw;
        data_read = rb.decode("utf-8");
    } else {
        rs: str = raw;
        data_read = rs;
    }
    raw2 = resp2.read();
    data_b64 = "";
    if isinstance(raw2, bytes) {
        rb2: bytes = raw2;
        data_b64 = rb2.decode("utf-8");
    } else {
        rs2: str = raw2;
        data_b64 = rs2;
    }
    return {
        "m_get": r.get_method(),
        "m_post": r2.get_method(),
        "m_put": r3.get_method(),
        "type": r.type,
        "host": r.host,
        "selector": r.selector,
        "full_url": r.full_url,
        "frag": r.fragment,
        "has_h": r.has_header("X-test"),
        "has_h2": r.has_header("nope"),
        "dlen": dlen,
        "rh": request_host(r),
        "p2u": pathname2url("/tmp/a b"),
        "p2u_s": pathname2url("/tmp/a b", True),
        "u2p": url2pathname("/tmp/a%20b"),
        "phl": parse_http_list("a, \"b,c\", d"),
        "pkl": parse_keqv_list(["k=v", "x=\"y z\""]),
        "fup": _fup_na(mgr.find_user_password("realm1", "http://ex.com/x/deep")),
        "fup_dp": _fup_na(mgr.find_user_password("realm1", "http://ex.com/y")),
        "fup_miss": _fup_na(mgr.find_user_password("nope", "http://ex.com/x")),
        "fup_d": _fup_na(mgrd.find_user_password("zzz", "http://ex.com/a/b")),
        "proxies": ph.proxies,
        "pb1": proxy_bypass_environment("www.ex.com", ph.proxies),
        "pb2": proxy_bypass_environment("other.com", ph.proxies),
        "pb3": proxy_bypass_environment("ex.com", ph.proxies),
        "op": 1 if op != None else 0,
        "data_read": data_read,
        "data_b64": data_b64
    };
}
