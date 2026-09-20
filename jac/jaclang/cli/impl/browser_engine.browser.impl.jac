import json;
import os;
import re;
import subprocess;
import time;
import from pathlib { Path }
import from http.client { HTTPResponse }
import from urllib.request { urlopen }


impl get_cache_dir -> Path {
    env = os.environ.get("JACBROWSER_CACHE");
    return Path(env) if env else (Path.home() / ".cache" / "jacbrowser");
}

impl _find_chrome -> str {
    env = os.environ.get("JACBROWSER_CHROME");
    if env {
        return env;
    }
    import from shutil { which }
    for name in [
        "google-chrome",
        "google-chrome-stable",
        "chromium",
        "chromium-browser"
    ] {
        path = which(name);
        if path {
            return path;
        }
    }
    for app in [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        str(
            Path.home() / "Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        ),
        "/opt/google/chrome/chrome",

    ] {
        if Path(app).exists() {
            return app;
        }
    }

    for pw in [
        Path.home() / ".cache" / "ms-playwright",
        Path.home() / "Library" / "Caches" / "ms-playwright",

    ] {
        if not pw.exists() {
            continue;
        }
        for d in sorted(pw.`glob("chromium-*"), reverse=True) {
            for rel in [
                "chrome-linux64/chrome",
                "chrome-linux/chrome",
                "chrome-mac/Chromium.app/Contents/MacOS/Chromium"
            ] {
                exe = d / rel;
                if exe.exists() {
                    return str(exe);
                }
            }
        }
    }
    raise FileNotFoundError("no Chrome/Chromium found; set JACBROWSER_CHROME");
}

impl _state_path(session: str) -> Path {
    return get_cache_dir() / f"session-{session}.json";
}

impl _refs_path(session: str) -> Path {
    return get_cache_dir() / f"refs-{session}.json";
}

impl _pid_alive(pid: int) -> bool {
    try {
        os.kill(pid, 0);
        return True;
    } except OSError {
        return False;
    }
}

impl _http_json(port: int, path: str) -> any {
    url = f"http://127.0.0.1:{port}{path}";
    opened: HTTPResponse = urlopen(url, timeout=5);
    with opened as r {
        return json.loads(r.read());
    }
}

impl _page_ws(port: int) -> str {
    for t in _http_json(port, "/json") {
        if t.get("type") == "page" and t.get("webSocketDebuggerUrl") {
            return t["webSocketDebuggerUrl"];
        }
    }

    browser_ws = _http_json(port, "/json/version")["webSocketDebuggerUrl"];
    cdp = CDP(ws_url=browser_ws);
    cdp.call("Target.createTarget", {"url": "about:blank"});
    cdp.close();
    for t in _http_json(port, "/json") {
        if t.get("type") == "page" and t.get("webSocketDebuggerUrl") {
            return t["webSocketDebuggerUrl"];
        }
    }
    raise RuntimeError("could not obtain a page target");
}

impl load_state(session: str) -> (dict[str, any] | None) {
    p = _state_path(session);
    if p.exists() {
        return json.loads(p.read_text());
    }
    return None;
}

impl _parse_viewport(spec: str) -> tuple[int, int] {
    m = re.fullmatch(r"(\d+)\s*[xX,]\s*(\d+)", spec.strip());
    if not m {
        raise ValueError(f"invalid viewport '{spec}' (expected WIDTHxHEIGHT)");
    }
    return (int(m.group(1)), int(m.group(2)));
}

impl _chrome_args(chrome: str, profile: Path, viewport: str) -> list[str] {
    (w, h) = _parse_viewport(viewport);
    return [
        chrome,
        "--headless=new",
        "--remote-debugging-port=0",
        f"--user-data-dir={profile}",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-dev-shm-usage",
        f"--window-size={w},{h}",
        "--use-angle=swiftshader",
        "--enable-unsafe-swiftshader",
        "--no-sandbox",
        "about:blank",

    ];
}

impl _calibrate_viewport(port: int, w: int, h: int) {
    try {
        cdp = CDP(ws_url=_page_ws(port));
        iw = _eval(cdp, "window.innerWidth");
        ih = _eval(cdp, "window.innerHeight");
        cdp.close();
        if iw == w and ih == h {
            return;
        }
        tid = None;
        for t in _http_json(port, "/json") {
            if t.get("type") == "page" {
                tid = t.get("id");
                break;
            }
        }
        if tid is None {
            return;
        }
        bws = _http_json(port, "/json/version")["webSocketDebuggerUrl"];
        bcdp = CDP(ws_url=bws);
        win = bcdp.call("Browser.getWindowForTarget", {"targetId": tid});
        b = win["bounds"];
        bcdp.call(
            "Browser.setWindowBounds",
            {
                "windowId": win["windowId"],
                "bounds": {
                    "width": b["width"] + (w - iw),
                    "height": b["height"] + (h - ih)
                }
            }
        );
        bcdp.close();
    } except Exception {}
}

impl launch(session: str = "default", viewport: str = "1280x720") -> dict[str, any] {
    st = load_state(session);
    if st and _pid_alive(st["pid"]) {
        try {
            _http_json(st["port"], "/json/version");
            return st;
        } except OSError {}
    }
    cache = get_cache_dir();
    cache.mkdir(parents=True, exist_ok=True);
    profile = cache / f"profile-{session}";
    chrome = _find_chrome();
    proc = subprocess.Popen(
        _chrome_args(chrome, profile, viewport),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    );

    port_file = profile / "DevToolsActivePort";
    port_file.unlink(missing_ok=True);
    port: (int | None) = None;
    for _ in range(100) {
        if port_file.exists() {
            port = int(port_file.read_text().splitlines()[0]);
            break;
        }
        time.sleep(0.1);
    }
    if port is None {
        proc.kill();
        raise RuntimeError("Chrome failed to start (no DevToolsActivePort)");
    }
    (vw, vh) = _parse_viewport(viewport);
    _calibrate_viewport(port, vw, vh);
    st = {"session": session, "pid": proc.pid, "port": port};
    _state_path(session).write_text(json.dumps(st));
    return st;
}

impl connect(session: str = "default") -> CDP {
    st = load_state(session);
    if (not st) or (not _pid_alive(st["pid"])) {
        raise RuntimeError(
            f"no live browser for session '{session}'; run `open` first"
        );
    }
    return CDP(ws_url=_page_ws(st["port"]));
}
