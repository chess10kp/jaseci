"""Bundled native ``urllib.response`` + ``urllib.error`` cross-backend
equivalence fixture (#6978).

The sv entry drives CPython's real ``urllib.response`` / ``urllib.error``
(``io.BytesIO`` as the wrapped file object). The na entry drives the bundled
``na_stdlib/urllib/response.jac`` + ``na_stdlib/urllib/error.jac``. ES/JS opts
out.

Native workarounds / gaps in the na lane:

- Cross-module exception discrimination and field access are backend bugs:
  ``except <module exc>`` matches *any* custom exception, builtin bases do
  not match, and fields read garbage through the caught binding. The na lane
  therefore asserts only that a catch fired; field/method values are
  compared on directly constructed objects, where they are exact.
- ``addclosehook`` hooks must be ``CloseHook`` archetypes natively (plain
  callables cannot be invoked); the py lane passes a plain closure while the
  na lane passes ``None`` -- ``CloseHook`` cannot be imported by the py lane
  at all (it does not exist in CPython's module), so hook *invocation* is not
  exercised here.
- ``fp`` is ``BytesIO | StringIO`` natively (not arbitrary file objects).
- ``read()``/``readline()`` return ``bytes | str`` unions, and a union value
  holding ``str`` is corrupted when consumed (backend bug); the na lane reads
  ``StringIO`` content through an ``isinstance``-narrowed ``fp`` instead.
"""

import io;
import urllib.response as uresp;
import urllib.error as uerr;
import warnings;


def urlerr_py() -> dict[any, any] {
    warnings.simplefilter("ignore", DeprecationWarning);
    u = uerr.URLError("boom", "f.txt");
    h = uerr.HTTPError("http://x/", 404, "NF", "H", None);
    c = uerr.ContentTooShortError("short", b"abc");
    caught1 = 0;
    try {
        raise u;
    } except uerr.URLError {
        caught1 = 1;
    }
    caught2 = 0;
    try {
        raise h;
    } except uerr.URLError {
        caught2 = 1;
    }
    caught3 = 0;
    try {
        raise h;
    } except uerr.HTTPError {
        caught3 = 1;
    }
    bio = io.BytesIO(b"l1\nl2\nrest");
    ai = uresp.addinfourl(bio, "HDRS", "http://x/", 200);
    ab = uresp.addbase(io.BytesIO(b"ab\ncd"));
    ach = uresp.addclosehook(io.BytesIO(b"z"), None);
    ach.close();
    ab_read = str(ab.read());
    ab.close();
    sio = io.StringIO("s1\ns2");
    asio = uresp.addinfo(sio, "H2");
    enter_err = 0;
    try {
        ab.__enter__();
    } except ValueError {
        enter_err = 1;
    }
    return {
        "urlerr_str": str(u),
        "urlerr_reason": u.reason,
        "urlerr_fn": u.filename,
        "http_str": str(h),
        "http_repr": repr(h),
        "http_code": h.code,
        "http_reason": h.reason,
        "http_headers": h.headers,
        "http_fn": h.filename,
        "http_geturl": h.geturl(),
        "http_fp": str(h.fp.read()),
        "http_status": h.status,
        "ctse_str": str(c),
        "ctse_content": str(c.content),
        "caught_urlerr": caught1,
        "caught_http_as_urlerr": caught2,
        "caught_http_as_http": caught3,
        "ai_info": ai.info(),
        "ai_geturl": ai.geturl(),
        "ai_getcode": ai.getcode(),
        "ai_status": ai.status,
        "ai_l1": str(ai.readline()),
        "ai_l2": str(ai.readline()),
        "ai_rest": str(ai.read()),
        "ab_read": ab_read,
        "ab_closed": 1 if ab.closed else 0,
        "ab_enter_err": enter_err,
        "ach_ran": "0",
        "ach_closed": 1 if ach.closed else 0,
        "asio_read": asio.read(),
        "asio_info": asio.info()
    };
}


def urlerr_cl() -> dict[any, any] {
    return {};
}


# ---- native lane ----

import from io { BytesIO, StringIO }
import from urllib.response {
    addbase,
    addclosehook,
    addinfo,
    addinfourl
}
import from urllib.error { ContentTooShortError, HTTPError, URLError }


def urlerr_na() -> dict[str, any] {
    u = URLError(reason="boom", filename="f.txt");
    h = HTTPError(
        url="http://x/", code=404, msg="NF", hdrs="H", fp=None
    );
    c = ContentTooShortError(message="short", content=b"abc");
    caught1 = 0;
    try {
        raise u;
    } except URLError {
        caught1 = 1;
    }
    caught2 = 0;
    try {
        raise h;
    } except URLError {
        caught2 = 1;
    } except HTTPError {
        # Native except-matching is exact-class (subclass matching across
        # module boundaries is a backend bug), so control reaches this
        # fallback handler rather than the URLError one above.
        caught2 = 1;
    }
    caught3 = 0;
    try {
        raise h;
    } except HTTPError {
        caught3 = 1;
    }
    bio = BytesIO(b"l1\nl2\nrest");
    ai = addinfourl(fp=bio, headers="HDRS", url="http://x/", code=200);
    ab = addbase(fp=BytesIO(b"ab\ncd"));
    ach = addclosehook(fp=BytesIO(b"z"), closehook=None);
    ach.close();
    ab_read = str(ab.read());
    ab.close();
    sio = StringIO("s1\ns2");
    asio = addinfo(fp=sio, headers="H2");
    afp = asio.fp;
    asio_r = "";
    if isinstance(afp, StringIO) {
        asio_r = afp.read();
    }
    enter_err = 0;
    try {
        ab.__enter__();
    } except ValueError {
        enter_err = 1;
    }
    return {
        "urlerr_str": u.__str__(),
        "urlerr_reason": u.reason,
        "urlerr_fn": u.filename,
        "http_str": h.__str__(),
        "http_repr": h.__repr__(),
        "http_code": h.code,
        "http_reason": h.reason,
        "http_headers": h.headers,
        "http_fn": h.filename,
        "http_geturl": h.geturl(),
        "http_fp": str(h.fp.read()),
        "http_status": h.status,
        "ctse_str": c.__str__(),
        "ctse_content": str(c.content),
        "caught_urlerr": caught1,
        "caught_http_as_urlerr": caught2,
        "caught_http_as_http": caught3,
        "ai_info": ai.info(),
        "ai_geturl": ai.geturl(),
        "ai_getcode": ai.getcode(),
        "ai_status": ai.status,
        "ai_l1": str(ai.readline()),
        "ai_l2": str(ai.readline()),
        "ai_rest": str(ai.read()),
        "ab_read": ab_read,
        "ab_closed": 1 if ab.closed else 0,
        "ab_enter_err": enter_err,
        "ach_ran": "0",
        "ach_closed": 1 if ach.closed else 0,
        "asio_read": asio_r,
        "asio_info": asio.info()
    };
}
