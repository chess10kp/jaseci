"""Native HTTP probes compared with prim_urllib_host.jac over one loopback server."""

import os;
import urllib.request;


def urllib_py -> dict[any, any] {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    resp = urllib.request.urlopen(base + "/hello");
    body = resp.read();
    return {
        "status": resp.status,
        "body": body.decode(),
        "body_length": len(body),
        "content_type": resp.getheader("Content-Type"),

    };
}


def urllib_redirect_py -> dict[any, any] {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    resp = urllib.request.urlopen(base + "/redirect");
    body = resp.read();
    return {"status": resp.status, "body": body.decode(), "body_length": len(body),};
}


import from urllib.request { urlopen }

def _status_of(resp0: any) -> int {
    import from urllib.request { HTTPResp }
    resp: HTTPResp = resp0;
    st = resp.status;
    if isinstance(st, int) {
        return st;
    }
    return -1;
}

def _blen_of(resp0: any) -> int {
    import from urllib.request { HTTPResp }
    resp: HTTPResp = resp0;
    return resp.body_length;
}

def urlopen_status_na -> int {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    return _status_of(urlopen(base + "/hello"));
}

def urlopen_body_length_na -> int {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    return _blen_of(urlopen(base + "/hello"));
}

def urlopen_redirect_status_na -> int {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    return _status_of(urlopen(base + "/redirect"));
}

def urlopen_redirect_body_length_na -> int {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    return _blen_of(urlopen(base + "/redirect"));
}
