import threading;
import from jaclang.cli.console { console }
import from jaclang.client { get_bun }
import from jaclang.client.client_bundle { ClientBundleError, MissingBunError }


def _build_vite_command(build_dir: Path, args: list[str]) -> list[str] {
    import from jaclang.client.targets.node_tooling_common { resolve_node_tool_entry }

    bun = _require_bun();
    `entry = resolve_node_tool_entry(build_dir, 'vite');
    if `entry is None {
        raise ClientBundleError(
            f"Vite is not installed under {build_dir / 'node_modules'}. "
            "Dependencies are installed before every build, so an absent "
            "vite means that install did not complete."
        ) from None;
    }
    return [bun, str(`entry)] + args;
}

def _build_vite_dev_command(
    build_dir: Path, config_rel: Path, port: int, host: str = ""
) -> list[str] {
    cmd = _build_vite_command(
        build_dir, ['--config', str(config_rel), '--port', str(port)]
    );
    if host {
        cmd.append('--host');
        cmd.append(host);
    } else {
        cmd.append('--host');
    }
    return cmd;
}

def _is_vite_ready_line(line: str) -> bool {
    line_lower = line.lower();
    for pattern in VITE_READY_PATTERNS {
        if pattern in line_lower {
            return True;
        }
    }
    return False;
}

def _is_vite_url_line(line: str) -> bool {
    for pattern in VITE_URL_PATTERNS {
        if pattern in line {
            return True;
        }
    }
    return False;
}

impl _forward_vite_output(
    proc: any,
    ready_event: any,
    sys_module: any,
    output_buffer: list[str],
    dispatch: any = None
) -> None {
    stream = proc.stdout;
    if stream is None {
        return;
    }
    try {
        while True {
            line = stream.readline();
            if not line {
                break;
            }
            if line.startswith(CLIENT_EVENT_PREFIX) {
                if dispatch is not None {
                    try {
                        dispatch(line);
                    } except Exception {}
                }
                continue;
            }

            if _is_vite_ready_line(line) {
                ready_event.set();
            }
            if ready_event.is_set() {
                if '[HMR]' in line or not _is_vite_url_line(line) {
                    sys_module.stdout.write(line);
                    sys_module.stdout.flush();
                }
            } else {
                output_buffer.append(line);
            }
        }
    } except Exception {}
}

impl ViteBundler._dispatch_client_event(self: ViteBundler, line: str) -> None {
    handler = self.on_client_event;
    if handler is None {
        return;
    }
    try {
        data = json.loads(line[len(CLIENT_EVENT_PREFIX):]);
    } except ValueError {
        return;
    }
    if not isinstance(data, dict) {
        return;
    }
    handler(str(data.get('slot') or ''), data.get('payload'));
}

impl ViteBundler.start_dev_server(
    self: ViteBundler,
    port: int = 3000,
    suppress_initial_output: bool = False,
    host: str = ""
) -> any {
    import sys;
    import time;
    import threading;
    import from jaclang.client { get_bun }

    if get_bun() is None {
        raise ClientBundleError(
            'Bun is required for dev server. Install manually: https://bun.sh'
        ) from None;
    }
    build_dir = self._get_client_dir();
    self._ensure_dev_index_html(build_dir);
    self._ensure_dev_dependencies(build_dir);

    dev_config = build_dir / 'configs' / 'vite.dev.config.js';
    if not dev_config.exists() {
        raise ClientBundleError(
            "Dev config not found. Call create_vite_config(is_dev=True) first."
        );
    }
    try {
        config_rel = dev_config.relative_to(build_dir);
    } except ValueError {
        config_rel = dev_config;
    }
    command = _build_vite_dev_command(build_dir, config_rel, port, host=host);

    self.dev_server_port = port;
    (build_dir / '.dev-port').unlink(missing_ok=True);
    if suppress_initial_output {
        process = self._start_vite_with_output_capture(command, build_dir, sys);
    } else {
        process = subprocess.Popen(command, cwd=build_dir);
    }
    return process;
}

def _dev_head_scripts -> str {
    import from jaclang.project.config { get_config }
    import from jaclang.client.serving { HeaderBuilder }

    config = get_config();
    client_cfg = config.get_plugin_config('client') if config else None;
    meta_data = client_cfg.get('app_meta_data', {}) if client_cfg else {};
    tags = HeaderBuilder(meta_data, 'dev').build_scripts();
    return ''.join(f'    {tag}\n' for tag in tags);
}

impl ViteBundler._ensure_dev_index_html(self: ViteBundler, build_dir: Path) -> None {
    index_html = build_dir / 'index.html';
    entry_relative = (self._client_app_dir() / 'compiled' / '_entry.js').relative_to(
        self._get_client_dir()
    ).as_posix();
    index_content = '''<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Jac App (Dev)</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module">
    if (import.meta.hot) {
      function report(d) {
        try { import.meta.hot.send("jac:client-error", d); } catch(e) {}
      }
      window.addEventListener("error", function(e) {
        report({
          type: e.error ? e.error.constructor.name : "Error",
          message: e.error ? e.error.message : e.message,
          stack: e.error ? e.error.stack : null,
          source: e.filename || null,
          line: e.lineno || null,
          column: e.colno || null
        });
      });
      window.addEventListener("unhandledrejection", function(e) {
        var r = e.reason;
        report({
          type: r instanceof Error ? r.constructor.name : "UnhandledPromiseRejection",
          message: r instanceof Error ? r.message : String(r),
          stack: r instanceof Error ? r.stack : null,
          source: null, line: null, column: null
        });
      });
      // react-refresh's global hook must install before React loads
      import("/@react-refresh").then(function(RefreshRuntime) {
        RefreshRuntime.injectIntoGlobalHook(window);
        window.$RefreshReg$ = function() {};
        window.$RefreshSig$ = function() { return function(type) { return type; }; };
        window.__jac_refresh_installed__ = true;
        return import(__JAC_DEV_ENTRY__);
      }).then(function() {
        // entry loaded cleanly: clears the client slot in /__build_status
        try { import.meta.hot.send("jac:client-ready"); } catch(e) {}
      }).catch(function(err) {
        report({
          type: err instanceof Error ? err.constructor.name : "Error",
          message: err instanceof Error ? err.message : String(err),
          stack: err instanceof Error ? err.stack : null,
          source: null, line: null, column: null,
          phase: "load"
        });
      });
    } else {
      import(__JAC_DEV_ENTRY__).catch(function() {});
    }
    </script>
  </body>
</html>
''';
    index_content = index_content.replace(
        '__JAC_DEV_ENTRY__', json.dumps('/' + entry_relative)
    );
    if head_scripts := _dev_head_scripts() {
        index_content = index_content.replace('  </head>', f'{head_scripts}  </head>');
    }
    index_html.write_text(index_content, encoding='utf-8');
}

impl ViteBundler._write_fast_refresh_plugin(
    self: ViteBundler, configs_dir: Path
) -> None {
    plugin_js = r'''// jac-fast-refresh.js (generated) - React Fast Refresh for Jac's compiled modules.
export default function jacFastRefresh() {
  return {
    name: "jac-fast-refresh",
    apply: "serve",
    transform(code, id) {
      const clean = id.split("?")[0];
      if (!clean.includes("/compiled/")) return null;
      if (!clean.endsWith(".js")) return null;
      if (code.indexOf("/*jac-fr*/") !== -1) return null;
      // The compiler stamps modules whose every export is a component; anything
      // unstamped (globs, helpers, router wiring) keeps full-reload semantics.
      if (code.indexOf("/*jac:refresh-boundary*/") === -1) return null;

      const modId = JSON.stringify(clean);
      // same self-accepting boundary @vitejs/plugin-react appends to JSX modules
      const header = '/*jac-fr*/import * as RefreshRuntime from "/@react-refresh";\n';

      const footer =
        "\nif (import.meta.hot) {" +
        "RefreshRuntime.__hmr_import(import.meta.url).then(function (currentExports) {" +
        "RefreshRuntime.registerExportsForReactRefresh(" + modId + ", currentExports);" +
        "import.meta.hot.accept(function (nextExports) {" +
        "if (!nextExports) return;" +
        "const inv = RefreshRuntime.validateRefreshBoundaryAndEnqueueUpdate(" + modId + ", currentExports, nextExports);" +
        "if (inv) import.meta.hot.invalidate(inv);" +
        "});" +
        "});" +
        "}\n";

      // header is exactly one line, so one empty mapping row keeps the sourcemap chain
      let map = null;
      try {
        map = this.getCombinedSourcemap();
        map.mappings = ";" + map.mappings;
      } catch (e) {
        map = null;
      }
      return { code: header + code + footer, map: map };
    }
  };
}
''';
    (configs_dir / 'jac-fast-refresh.js').write_text(plugin_js, encoding='utf-8');
}

impl ViteBundler._write_client_events_plugin(
    self: ViteBundler, configs_dir: Path
) -> None {
    plugin_js = (
        '// jac-client-events.js (generated) - raw dev-loop event transport.\n'
        '// This plugin resolves nothing, stores nothing and renders nothing.\n'
        '// It writes one tagged JSON line per event to stdout, the stream the\n'
        '// jac process already reads. That process is the side that maps a\n'
        '// compiled coordinate back to a .jac (or jac.toml) location, classifies\n'
        '// it, renders it with the same renderer `jac check` uses, and owns\n'
        '// .jac-status.json.\n'
        f'const PREFIX = "{CLIENT_EVENT_PREFIX}";\n'
    )
        + r'''
function emit(slot, payload) {
  try {
    process.stdout.write(PREFIX + JSON.stringify({ slot: slot, payload: payload }) + "\n");
  } catch (e) {}
}

// Called by jacErrorReporter with the browser's own payload, verbatim.
// A module-load failure means the app never came up, so it lands in the
// build-health slot; anything thrown after load is reported to the terminal
// but does not declare the build broken.
export function recordClientEvent(data) {
  const d = data || {};
  emit(d.phase === "load" ? "client" : "runtime", {
    "type": String(d.type || "Error"),
    "message": String(d.message || "client module load failed"),
    "stack": String(d.stack || ""),
    "source": String(d.source || ""),
    "line": Number(d.line || 0),
    "column": Number(d.column || 0),
    "phase": String(d.phase || ""),
  });
}

export default function jacClientEvents() {
  return {
    name: "jac-client-events",
    apply: "serve",
    configureServer(server) {
      let viteBroken = false;

      // Vite announces every transform/resolve failure on its HMR channel
      // (the payload that drives its own error overlay), and update/full-reload
      // on recovery. Mirror exactly those semantics onto the vite slot.
      const wrap = (chan) => {
        if (!chan || typeof chan.send !== "function" || chan.__jacClientEvents) return;
        chan.__jacClientEvents = true;
        const orig = chan.send.bind(chan);
        chan.send = (...args) => {
          try {
            const payload = args[0];
            if (payload && payload.type === "error" && payload.err) {
              // jac* payloads are the Jac and browser layers, tracked elsewhere
              if (!String(payload.err.plugin || "").startsWith("jac")) {
                const err = payload.err;
                viteBroken = true;
                emit("vite", {
                  "message": String(err.message || "Vite error"),
                  "stack": String(err.stack || ""),
                  "id": String(err.id || ""),
                  "plugin": String(err.plugin || ""),
                  "frame": String(err.frame || ""),
                  "loc": err.loc || null,
                });
              }
            } else if (
              payload
              && (payload.type === "update" || payload.type === "full-reload")
              && viteBroken
              // Jac-recovery reloads (jacBuildErrorOverlay) say nothing about
              // the Vite layer; with no client connected nothing will re-arm
              // a still-broken module, so keep the error latched.
              && !payload.jacTriggered
              && server.ws.clients
              && server.ws.clients.size > 0
            ) {
              viteBroken = false;
              emit("vite", null);
            }
          } catch (e) {}
          return orig(...args);
        };
      };
      wrap(server.ws);
      wrap(server.hot);

      // The dev index.html sends this after the entry module loads cleanly:
      // the only reliable "browser recovered" signal a server can get.
      const onReady = () => { emit("ready", null); };
      server.ws.on("jac:client-ready", onReady);
      // mirror wrap(): register on the HMR channel too if it is distinct
      if (server.hot && server.hot !== server.ws && typeof server.hot.on === "function") {
        try { server.hot.on("jac:client-ready", onReady); } catch (e) {}
      }
    },
  };
}
''';
    (configs_dir / 'jac-client-events.js').write_text(plugin_js, encoding='utf-8');
}

impl ViteBundler._start_vite_with_output_capture(
    self: ViteBundler, command: list[str], build_dir: Path, sys_module: any
) -> any {
    import threading;
    import time;
    process = subprocess.Popen(
        command,
        cwd=build_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    );
    ready_event = threading.Event();
    output_buffer: list[str] = [];
    output_thread = threading.Thread(
        target=_forward_vite_output,
        args=(
            process,
            ready_event,
            sys_module,
            output_buffer,
            self._dispatch_client_event
        ),
        daemon=True
    );
    output_thread.start();

    is_ready = ready_event.`wait(timeout=VITE_READY_TIMEOUT_SECONDS);
    if is_ready {
        port_file = build_dir / '.dev-port';
        for _ in range(40) {
            if port_file.exists() {
                break;
            }
            time.sleep(0.05);
        }
        try {
            self.dev_server_port = int(port_file.read_text().strip());
        } except (OSError, ValueError) {}
        console.print("  ✔ Vite dev server ready", style="success");
    } else {
        exit_code = process.poll();
        if exit_code is not None {
            console.error("  ✖ Vite dev server failed to start");
            if output_buffer {
                console.print("\n  Vite output:");
                for line in output_buffer {
                    sys_module.stdout.write(f"    {line}");
                }
                sys_module.stdout.flush();
            }
        } else {
            console.warning(
                f"  ⚠ Vite server may not be ready (timeout after {VITE_READY_TIMEOUT_SECONDS}s)"
            );
        }
    }
    return process;
}
