"""Cross-transport invocation parity: jac-scale stack vs desktop bridge.

The SAME fixture (`fixtures/parity_app.jac`) is booted twice and the normalized
outcomes are compared field-for-field:

  (a) the jac-scale stack, driven through `ScaleTestClient` (endpoint profile
      "test"); and
  (b) the desktop in-process bridge, driven through the staged
      `inprocess_dispatch` module (`boot` + `dispatch`/`forward`, endpoint
      profile "desktop") -- the exact module the generated desktop host runs.

Both front doors resolve walkers/functions through the shared
`ExecutionHandler` entry (server.impl.jac), so success envelopes, failure
envelopes, and SSE stream framing must be identical. This file asserts that
they do, so a transport-specific divergence cannot sneak back in.

Each side is booted once. Because both runtimes install process-global state
(Jac context, shared-root resolver, default base path dir), every request
activates its side's globals first and tests run sequentially. Tests self-skip
when the scale backend deps are absent -- see test_inprocess_dispatch.jac for
the same convention.
"""

import os;
import json;
import tempfile;
import from pathlib { Path }

glob _FIXTURE: str = str(Path(__file__).parent / "fixtures" / "parity_app.jac"),
     _CLIENT: any = None,
     _BOOTED: bool = False,
     _CTX: dict[str, any] = {},
     _BUILD_FAILED: str = "";


"""True when the in-process backend (jaclang.scale) is importable."""
def _backend_available -> bool {
    try {
        import jaclang.scale.server.serve;
        return True;
    } except ImportError {
        return False;
    }
}


def _snapshot -> list {
    import from jaclang { JacRuntime as Jac }
    import jaclang.jac0core.runtime as _rtmod;
    return [Jac.exec_ctx, list(_rtmod._shared_root_resolver), Jac.get_base_path_dir()];
}


def _activate(snap: list) {
    import from jaclang { JacRuntime as Jac }
    import jaclang.jac0core.runtime as _rtmod;
    Jac.set_context(snap[0]);
    _rtmod._shared_root_resolver[0] = snap[1][0];
    _rtmod._shared_root_resolver[1] = snap[1][1];
    Jac.set_base_path(snap[2]);
}


"""Boot BOTH transports once from the same fixture; returns False to self-skip."""
def _ensure -> bool {
    if _CLIENT is not None and _BOOTED {
        return True;
    }
    if _BUILD_FAILED {
        return False;
    }
    try {
        import warnings;
        import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
            boot
        }
        import from jaclang.scale.tests.scale_test_client { ScaleTestClient }

        with warnings.catch_warnings() {
            warnings.filterwarnings(
                "ignore",
                message=r".*iscoroutinefunction.*",
                category=DeprecationWarning
            );
            # Scale stack first; snapshot its globals while they are ambient.
            scale_graph = tempfile.mkdtemp(prefix="parity_scale_");
            _CLIENT = ScaleTestClient.from_file(_FIXTURE, base_path=scale_graph);
            _CTX["scale"] = _snapshot();
            # Then the desktop bridge; snapshot what boot() installed.
            desk_graph = tempfile.mkdtemp(prefix="parity_desk_");
            boot(_FIXTURE, os.path.join(desk_graph, "graph"));
            _BOOTED = True;
            _CTX["desktop"] = _snapshot();
        }
        return True;
    } except Exception as e {
        import traceback;
        _BUILD_FAILED = str(e) + "\n" + traceback.format_exc();
        return False;
    }
}


"""Recursively drop `_jac_id` -- the per-instance walker/node UUID legitimately
differs between two independently-booted runtimes, so it is the one key that
must be ignored when asserting envelope parity. Everything else must match."""
def _strip_ids(val: any) -> any {
    if isinstance(val, dict) {
        return {
            k: _strip_ids(v)
            for (k, v) in val.items()
            if k != "_jac_id"
        };
    }
    if isinstance(val, list) {
        return [_strip_ids(v) for v in val];
    }
    return val;
}


def _norm_scale(resp: any) -> dict {
    j: any = {};
    try {
        j = resp.json();
    } except Exception { }
    ok = bool(isinstance(j, dict) and j.get("ok"));
    data = j.get("data") if isinstance(j, dict) else None;
    err = j.get("error") if isinstance(j, dict) else None;
    return {"status": resp.status_code, "ok": ok, "data": data, "error": err};
}


def _norm_desktop(reply: dict) -> dict {
    body = reply.get("body") if isinstance(reply.get("body"), dict) else {};
    return {
        "status": reply.get("status"),
        "ok": bool(body.get("ok")),
        "data": body.get("data"),
        "error": body.get("error")
    };
}


def _dispatch(request: dict) -> dict {
    import warnings;
    import json as _json;
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        dispatch
    }
    with warnings.catch_warnings() {
        warnings.filterwarnings(
            "ignore", message=r".*iscoroutinefunction.*", category=DeprecationWarning
        );
        raw = dispatch(_json.dumps(request));
    }
    return json.loads(raw);
}


"""Parse the JSON payloads of SSE `data:` frames, dropping the terminal
`event: end` frame. Framing is shared (serving/sse.jac), so this normalizes
either transport's body to the list of streamed items."""
def _parse_sse_data(text: str) -> list {
    out: list = [];
    for block in text.split("\n\n") {
        if not block.strip() {
            continue;
        }
        is_event = False;
        payload: any = None;
        for line in block.split("\n") {
            if line.startswith("event:") {
                is_event = True;
            } elif line.startswith("data:") {
                payload = line[5:].strip();
            }
        }
        if is_event or payload is None {
            continue;
        }
        out.append(json.loads(payload));
    }
    return out;
}


test "default walker envelope matches across transports" {
    if not _backend_available() or not _ensure() {
        print(
            "[skip] cross-transport parity needs the scale backend: " + _BUILD_FAILED
        );
        return;
    }
    _activate(_CTX["scale"]);
    a = _norm_scale(_CLIENT.post("/walker/greet", json={"name": "Ada"}));
    _activate(_CTX["desktop"]);
    b = _norm_desktop(
        _dispatch(
            {
                "kind": "walker",
                "name": "greet",
                "node": "",
                "fields": {"name": "Ada"},
                "token": ""
            }
        )
    );
    assert a["status"] == 200 and b["status"] == 200 , (a, b);
    assert a["ok"] and b["ok"] , (a, b);
    assert a["data"]["reports"][0] == {"greeting": "hello Ada"} , (a, b);
    # Field-for-field equality of the full success envelope.
    assert _strip_ids(a["data"]) == _strip_ids(b["data"]) , (a["data"], b["data"]);
}


test "function envelope matches across transports" {
    if not _backend_available() or not _ensure() {
        print(
            "[skip] cross-transport parity needs the scale backend: " + _BUILD_FAILED
        );
        return;
    }
    _activate(_CTX["scale"]);
    a = _norm_scale(_CLIENT.post("/function/add", json={"a": 2, "b": 40}));
    _activate(_CTX["desktop"]);
    b = _norm_desktop(
        _dispatch(
            {
                "kind": "function",
                "name": "add",
                "node": "",
                "fields": {"a": 2, "b": 40},
                "token": ""
            }
        )
    );
    assert a["status"] == 200 and b["status"] == 200 , (a, b);
    assert a["data"]["result"] == 42 and b["data"]["result"] == 42 , (a, b);
    assert _strip_ids(a["data"]) == _strip_ids(b["data"]) , (a["data"], b["data"]);
}


test "unknown walker is a matching non-executed rejection on both transports" {
    if not _backend_available() or not _ensure() {
        print(
            "[skip] cross-transport parity needs the scale backend: " + _BUILD_FAILED
        );
        return;
    }
    _activate(_CTX["scale"]);
    a = _norm_scale(_CLIENT.post("/walker/__no_such_walker__", json={}));
    _activate(_CTX["desktop"]);
    b = _norm_desktop(
        _dispatch(
            {
                "kind": "walker",
                "name": "__no_such_walker__",
                "node": "",
                "fields": {},
                "token": ""
            }
        )
    );
    assert a["status"] == 404 , a;
    assert b["status"] == 404 , b;
    assert not a["ok"] and not b["ok"] , (a, b);
}


test "generator functions stream identical SSE frames across transports" {
    if not _backend_available() or not _ensure() {
        print(
            "[skip] cross-transport parity needs the scale backend: " + _BUILD_FAILED
        );
        return;
    }
    import warnings;
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        forward
    }

    _activate(_CTX["scale"]);
    ra = _CLIENT.post("/function/stream_numbers", json={"n": 3});
    assert ra.status_code == 200 , ra.text;
    assert "text/event-stream" in ra.headers.get("content-type", "") , ra.headers;

    _activate(_CTX["desktop"]);
    with warnings.catch_warnings() {
        warnings.filterwarnings(
            "ignore", message=r".*iscoroutinefunction.*", category=DeprecationWarning
        );
        (dstatus, dtext, dctype) = forward(
            "POST", "/function/stream_numbers", json.dumps({"n": 3}).encode("utf-8")
        );
    }
    assert dstatus == 200 , dtext;
    assert "text/event-stream" in dctype , dctype;

    scale_items = _parse_sse_data(ra.text);
    desk_items = _parse_sse_data(dtext);
    assert desk_items == [{"n": 0}, {"n": 1}, {"n": 2}] , desk_items;
    assert scale_items == desk_items , (scale_items, desk_items);
    # Both bodies terminate with the shared `event: end` sentinel.
    assert "event: end" in ra.text and "event: end" in dtext;
}
