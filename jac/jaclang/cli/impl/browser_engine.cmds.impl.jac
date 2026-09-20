import base64;
import json;
import os;
import re;
import sys;
import time;
import from pathlib { Path }


impl _eval(cdp: CDP, expr: str) -> any {
    res = cdp.call(
        "Runtime.evaluate",
        {"expression": expr, "returnByValue": True, "awaitPromise": True}
    );
    details = res.get("exceptionDetails");
    if details {
        desc = (details.get("exception") or {}).get("description");
        raise RuntimeError(desc or details.get("text", "JS exception"));
    }
    return res.get("result", {}).get("value");
}

impl _load_refs(session: str) -> dict[str, any] {
    p = _refs_path(session);
    if p.exists() {
        return json.loads(p.read_text());
    }
    return {};
}

impl _resolve_object_id(cdp: CDP, session: str, selector: str) -> (str | None) {
    if selector.startswith("@") {
        backend = _load_refs(session).get(selector[1:]);
        if backend is None {
            raise RuntimeError(f"unknown ref '{selector}'; run `snapshot` first");
        }
        try {
            res = cdp.call("DOM.resolveNode", {"backendNodeId": backend});
            return res["object"]["objectId"];
        } except Exception {
            return None;
        }
    }
    res = cdp.call(
        "Runtime.evaluate",
        {"expression": f"document.querySelector({json.dumps(selector)})"}
    );
    return res.get("result", {}).get("objectId");
}

impl _locate(
    cdp: CDP, session: str, selector: str, timeout: float = 10.0
) -> tuple[float, float] {
    cdp.call("DOM.enable");
    deadline = time.time() + timeout;
    prev: (tuple[float, float] | None) = None;
    last_err = "element not found";

    while time.time() < deadline {
        oid = _resolve_object_id(cdp, session, selector);
        if oid is None {
            last_err = "element not found";
            prev = None;
            time.sleep(0.1);
            continue;
        }
        try {
            res = cdp.call(
                "Runtime.callFunctionOn",
                {
                    "functionDeclaration": ACTIONABILITY_JS,
                    "objectId": oid,
                    "returnByValue": True
                }
            );
        } except RuntimeError as e {
            last_err = str(e);
            prev = None;
            time.sleep(0.1);
            continue;
        }
        st: dict[str, any] = res.get("result", {}).get("value") or {};
        if not st.get("ok") {
            last_err = str(st.get("reason", "not actionable"));
            prev = None;
            time.sleep(0.1);
            continue;
        }
        if not st.get("hitOk", True) {
            last_err = (
                f"point ({int(st['x'])},{int(st['y'])}) is covered by {st.get('hit')}"
            );
            prev = None;
            time.sleep(0.1);
            continue;
        }
        cx = float(st["x"]);
        cy = float(st["y"]);
        if prev is not None and abs(cx - prev[0]) < 1 and abs(cy - prev[1]) < 1 {
            return (cx, cy);
        }
        prev = (cx, cy);

        time.sleep(0.15);
    }
    raise RuntimeError(f"{selector} not actionable: {last_err}");
}

impl _real_click(cdp: CDP, x: float, y: float) {
    cdp.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y});
    base = {"x": x, "y": y, "button": "left", "clickCount": 1};
    cdp.call("Input.dispatchMouseEvent", {"type": "mousePressed"} | base);
    cdp.call("Input.dispatchMouseEvent", {"type": "mouseReleased"} | base);
}

impl _type_text(cdp: CDP, text: str) {
    for ch in text {
        cdp.call("Input.dispatchKeyEvent", {"type": "keyDown", "text": ch});
        cdp.call("Input.dispatchKeyEvent", {"type": "keyUp"});
    }
}

impl _insert_text(cdp: CDP, text: str) {
    cdp.call("Input.insertText", {"text": text});
}

impl _key_code(ch: str) -> str {
    if ch.isalpha() {
        return "Key" + ch.upper();
    }
    if ch.isdigit() {
        return "Digit" + ch;
    }
    return ch;
}

impl _press(cdp: CDP, key: str, modifiers: int = 0) {
    vk = KEY_CODES.get(key, 0);
    code = key;
    down = {"type": "keyDown", "key": key, "modifiers": modifiers};
    if vk {
        down["windowsVirtualKeyCode"] = vk;
    } elif len(key) == 1 {
        code = _key_code(key);
        down["windowsVirtualKeyCode"] = ord(key.upper());
        if modifiers == 0 {
            down["text"] = key;
        }
    }
    down["code"] = code;
    cdp.call("Input.dispatchKeyEvent", down);
    cdp.call(
        "Input.dispatchKeyEvent",
        {"type": "keyUp", "key": key, "code": code, "modifiers": modifiers}
    );
}

impl cmd_open(session: str, url: (str | None), viewport: str = "1280x720") -> str {
    launch(session, viewport);
    if url {
        return cmd_navigate(session, url);
    }
    return "browser ready (about:blank)";
}

impl cmd_navigate(session: str, url: str) -> str {
    if not re.`match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", url) {
        url = "https://" + url;
    }
    cdp = connect(session);
    cdp.call("Page.enable");
    cdp.call("Page.navigate", {"url": url});

    deadline = time.time() + 30;
    while time.time() < deadline {
        if _eval(cdp, "document.readyState") == "complete" {
            break;
        }
        time.sleep(0.1);
    }
    href = _eval(cdp, "location.href");
    cdp.close();
    return f"navigated to {href}";
}

impl cmd_eval(session: str, expr: str) -> any {
    cdp = connect(session);
    out = _eval(cdp, expr);
    cdp.close();
    return out;
}

impl cmd_click(session: str, selector: str) -> str {
    cdp = connect(session);
    (x, y) = _locate(cdp, session, selector);
    _real_click(cdp, x, y);
    cdp.close();
    return f"clicked {selector} at ({int(x)},{int(y)})";
}

impl cmd_type(session: str, selector: str, text: str) -> str {
    cdp = connect(session);
    (x, y) = _locate(cdp, session, selector);
    _real_click(cdp, x, y);
    _type_text(cdp, text);
    cdp.close();
    return f"typed into {selector}";
}

impl cmd_fill(session: str, selector: str, text: str) -> str {
    cdp = connect(session);
    (x, y) = _locate(cdp, session, selector);
    _real_click(cdp, x, y);
    _press(cdp, "a", modifiers=2);
    _press(cdp, "Delete");
    _insert_text(cdp, text);
    cdp.close();
    return f"filled {selector}";
}

impl cmd_press(session: str, key: str) -> str {
    cdp = connect(session);
    _press(cdp, key);
    cdp.close();
    return f"pressed {key}";
}

impl cmd_get(session: str, what: str, selector: (str | None)) -> any {
    if what == "url" {
        return cmd_eval(session, "location.href");
    }
    if what == "title" {
        return cmd_eval(session, "document.title");
    }
    if what == "text" {
        js = (
            f"(()=>{{const el=document.querySelector({json.dumps(selector)});"
            "return el?el.innerText:null;})()"
        );
        return cmd_eval(session, js);
    }
    raise ValueError(f"unknown get target: {what}");
}

impl cmd_screenshot(session: str, path: (str | None)) -> str {
    cdp = connect(session);
    res = cdp.call("Page.captureScreenshot", {"format": "png"});
    data = base64.b64decode(res["data"]);
    cdp.close();
    out_path = path;
    if not out_path {
        cache = get_cache_dir();
        cache.mkdir(parents=True, exist_ok=True);
        out_path = str(cache / f"screenshot-{int(time.time())}.png");
    }
    Path(out_path).write_bytes(data);
    return f"screenshot saved to {out_path} ({len(data)} bytes)";
}

impl _remote_obj_str(ro: dict[str, any]) -> str {
    if "value" in ro {
        v = ro["value"];
        return v if isinstance(v, str) else json.dumps(v);
    }
    if ro.get("unserializableValue") {
        return ro["unserializableValue"];
    }
    if ro.get("description") {
        return ro["description"];
    }
    return ro.get("type", "?");
}

impl _format_console_event(method: str, params: dict[str, any]) -> (str | None) {
    if method == "Runtime.consoleAPICalled" {
        kind = params.get("type", "log");
        parts = [_remote_obj_str(a) for a in params.get("args", [])];
        return f"[{kind}] " + " ".join(parts);
    }
    if method == "Runtime.exceptionThrown" {
        d = params.get("exceptionDetails", {});
        desc = (d.get("exception") or {}).get("description")
            or d.get("text", "uncaught exception");
        return f"[error] {desc}";
    }
    if method == "Log.entryAdded" {
        e = params.get("entry", {});
        if e.get("source") == "console-api" {
            return None;
        }
        url = e.get("url", "");
        loc = f" ({url}:{e.get('lineNumber')})" if url else "";
        return f"[{e.get('level', 'info')}] {e.get('text', '')}{loc}";
    }
    return None;
}

impl cmd_console(session: str, clear: bool = False) -> str {
    cdp = connect(session);

    cdp.call("Runtime.enable");
    cdp.call("Log.enable");
    events = cdp.drain_events();
    if clear {
        cdp.call("Runtime.discardConsoleEntries");
        cdp.call("Log.clear");
    }
    cdp.close();
    lines = [];
    for ev in events {
        line = _format_console_event(ev.get("method", ""), ev.get("params", {}));
        if line is not None {
            lines.append(line);
        }
    }
    return "\n".join(lines) if lines else "(no console output)";
}

impl cmd_wait(session: str, arg: str, timeout: float = 30.0) -> str {
    if re.fullmatch(r"\d+", arg) {
        ms = int(arg);
        time.sleep(ms / 1000);
        return f"waited {ms}ms";
    }
    cdp = connect(session);
    try {
        _locate(cdp, session, arg, timeout=timeout);
    } finally {
        cdp.close();
    }
    return f"waited for {arg}";
}

impl cmd_scroll(session: str, target: str, amount: (int | None) = None) -> str {
    cdp = connect(session);
    try {
        deltas = {"down": (0, 1), "up": (0, -1), "right": (1, 0), "left": (-1, 0)};
        if target in deltas {
            (sx, sy) = deltas[target];

            amt = str(amount)
                if amount is not None
                else ("innerWidth * 0.8" if sx else "innerHeight * 0.8");
            _eval(
                cdp,
                f"window.scrollBy({{left: {sx} * ({amt}), top: {sy} * ({amt}),"
                " behavior: 'instant'})"
            );
        } elif target == "top" {
            _eval(cdp, "window.scrollTo(0, 0)");
        } elif target == "bottom" {
            _eval(cdp, "window.scrollTo(0, document.documentElement.scrollHeight)");
        } else {
            (x, y) = _locate(cdp, session, target);
            return f"scrolled {target} into view at ({int(x)},{int(y)})";
        }
        pos = _eval(cdp, "JSON.stringify([Math.round(scrollX), Math.round(scrollY)])");
    } finally {
        cdp.close();
    }
    return f"scrolled to {pos}";
}

impl _walk_ax(
    ax: dict[str, any],
    by_id: dict[str, any],
    depth: int,
    lines: list[str],
    refs: dict[str, any]
) {
    role = (ax.get("role") or {}).get("value", "");
    name = (ax.get("name") or {}).get("value", "");
    ignored = ax.get("ignored", False);
    next_depth = depth;
    if (not ignored) and role {
        ref_str = "";
        backend = ax.get("backendDOMNodeId");
        if (role in INTERACTIVE_ROLES or name) and backend is not None {
            rid = f"e{len(refs) + 1}";
            refs[rid] = backend;
            ref_str = f"@{rid} ";
        }
        label = f' "{name}"' if name else "";
        lines.append("  " * depth + f"{ref_str}{role}{label}");
        next_depth = depth + 1;
    }
    for cid in ax.get("childIds", []) {
        child = by_id.get(cid);
        if child {
            _walk_ax(child, by_id, next_depth, lines, refs);
        }
    }
}

impl cmd_snapshot(session: str) -> str {
    cdp = connect(session);
    cdp.call("DOM.enable");
    cdp.call("Accessibility.enable");
    nodes = cdp.call("Accessibility.getFullAXTree").get("nodes", []);
    cdp.close();
    by_id = {};
    for n in nodes {
        by_id[n["nodeId"]] = n;
    }
    child_ids = set();
    for n in nodes {
        for c in n.get("childIds", []) {
            child_ids.add(c);
        }
    }
    roots = [
        n
        for n in nodes
        if n["nodeId"] not in child_ids
    ];
    lines = [];
    refs = {};
    for r in roots {
        _walk_ax(r, by_id, 0, lines, refs);
    }
    _refs_path(session).write_text(json.dumps(refs));
    return "\n".join(lines);
}

impl _cookie_param(ck: dict[str, any]) -> dict[str, any] {
    c = {
        "name": ck["name"],
        "value": ck["value"],
        "domain": ck.get("domain", ""),
        "path": ck.get("path", "/"),
        "httpOnly": ck.get("httpOnly", False),
        "secure": ck.get("secure", False),

    };
    if ck.get("expires", -1) >= 0 {
        c["expires"] = ck["expires"];
    }
    if ck.get("sameSite") {
        c["sameSite"] = ck["sameSite"];
    }
    return c;
}

impl cmd_state(session: str, sub: str, path: str) -> str {
    cdp = connect(session);
    cdp.call("Network.enable");
    if sub == "save" {
        cookies = cdp.call("Network.getAllCookies").get("cookies", []);
        local = _eval(cdp, "JSON.stringify(window.localStorage)");
        url = _eval(cdp, "location.href");
        cdp.close();
        Path(path).write_text(
            json.dumps({"url": url, "cookies": cookies, "localStorage": local})
        );
        return f"saved {len(cookies)} cookies to {path}";
    } elif sub == "load" {
        data = json.loads(Path(path).read_text());
        cookies = data.get("cookies", []);
        if cookies {
            cdp.call(
                "Network.setCookies", {"cookies": [_cookie_param(ck) for ck in cookies]}
            );
        }
        local = data.get("localStorage");
        if local and local != "{}" {
            _eval(
                cdp,
                f"(()=>{{const o={local};for(const k in o)localStorage.setItem(k,o[k]);}})()"
            );
        }
        cdp.close();
        return f"loaded {len(cookies)} cookies from {path}";
    }
    cdp.close();
    raise ValueError(f"unknown state subcommand '{sub}' (use save|load)");
}

impl cmd_sessions(session: str) -> str {
    cache = get_cache_dir();
    if not cache.exists() {
        return "(no sessions)";
    }
    lines = [];
    for f in sorted(cache.`glob("session-*.json")) {
        try {
            st = json.loads(f.read_text());
            status = "alive" if _pid_alive(st["pid"]) else "dead";
            marker = "*" if st.get("session") == session else " ";
            lines.append(
                f"{marker} {st.get('session')}  pid={st['pid']} port={st['port']} [{status}]"
            );
        } except Exception {}
    }
    return "\n".join(lines) if lines else "(no sessions)";
}

impl cmd_close(session: str) -> str {
    st = load_state(session);
    if st and _pid_alive(st["pid"]) {
        try {
            os.kill(st["pid"], 15);
        } except OSError {}
    }
    _state_path(session).unlink(missing_ok=True);
    _refs_path(session).unlink(missing_ok=True);
    return "closed";
}

def _need(rest: list[str], n: int, usage: str) {
    if len(rest) < n {
        raise ValueError(f"usage: {usage}");
    }
}

impl main(argv: list[str]) -> int {
    session = os.environ.get("JACBROWSER_SESSION", "default");
    if not argv {
        sys.stdout.write(
            "usage: browser_engine.jac <open|navigate|eval|click|type|fill|press|get|wait|scroll|console|snapshot|screenshot|state|sessions|close> ...\n"
        );
        return 1;
    }
    cmd = argv[0];
    rest = argv[1:];
    out: any = "";
    try {
        if cmd == "open" {
            out = cmd_open(session, rest[0] if rest else None);
        } elif cmd == "navigate" or cmd == "goto" {
            _need(rest, 1, "navigate <url>");
            out = cmd_navigate(session, rest[0]);
        } elif cmd == "eval" {
            _need(rest, 1, "eval <expression>");
            out = cmd_eval(session, rest[0]);
        } elif cmd == "click" {
            _need(rest, 1, "click <selector|@ref>");
            out = cmd_click(session, rest[0]);
        } elif cmd == "type" {
            _need(rest, 2, "type <selector|@ref> <text>");
            out = cmd_type(session, rest[0], rest[1]);
        } elif cmd == "fill" {
            _need(rest, 2, "fill <selector|@ref> <text>");
            out = cmd_fill(session, rest[0], rest[1]);
        } elif cmd == "press" {
            _need(rest, 1, "press <key>");
            out = cmd_press(session, rest[0]);
        } elif cmd == "get" {
            _need(rest, 1, "get <title|url|text|html|value> [selector]");
            out = cmd_get(session, rest[0], rest[1] if len(rest) > 1 else None);
        } elif cmd == "wait" {
            _need(rest, 1, "wait <selector|@ref>");
            out = cmd_wait(session, rest[0]);
        } elif cmd == "scroll" {
            _need(rest, 1, "scroll <up|down|top|bottom|selector> [amount]");
            out = cmd_scroll(session, rest[0], int(rest[1]) if len(rest) > 1 else None);
        } elif cmd == "scrollintoview" {
            _need(rest, 1, "scrollintoview <selector|@ref>");
            out = cmd_scroll(session, rest[0]);
        } elif cmd == "console" {
            out = cmd_console(session, "--clear" in rest or "clear" in rest);
        } elif cmd == "snapshot" {
            out = cmd_snapshot(session);
        } elif cmd == "screenshot" {
            out = cmd_screenshot(session, rest[0] if rest else None);
        } elif cmd == "state" {
            _need(rest, 2, "state <save|load> <path>");
            out = cmd_state(session, rest[0], rest[1]);
        } elif cmd == "sessions" {
            out = cmd_sessions(session);
        } elif cmd == "close" {
            out = cmd_close(session);
        } else {
            sys.stdout.write(f"unknown command: {cmd}\n");
            return 1;
        }
    } except Exception as e {
        sys.stderr.write(f"error: {e}\n");
        return 1;
    }
    sys.stdout.write((out if isinstance(out, str) else json.dumps(out)) + "\n");
    return 0;
}
