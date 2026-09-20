import from jaclang.cli.console { console }


impl ViteBundler._get_client_dir(self: ViteBundler) -> Path {
    if self.build_dir is not None {
        return self.build_dir;
    }
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if config is not None {
            config_root = config.project_root;
            if config_root is not None {
                cfg_root = config_root.resolve();
                cur_dir = self.project_dir.resolve();
                if cur_dir == cfg_root or cfg_root in cur_dir.parents {
                    return config.get_client_dir();
                }
            }
        }
    } except ImportError {}

    return self.project_dir / '.jac' / 'client';
}

impl ViteBundler._client_app_dir(self: ViteBundler) -> Path {
    if self.build_dir is not None {
        return self.build_dir;
    }
    client_dir = self._get_client_dir();
    try {
        import from jaclang.project.config { get_config }
        import from jaclang.project.client_paths { client_workspace_app }
        app = client_workspace_app(get_config(), self.config_loader.entry_path);
        if app is not None {
            return client_dir / app.name;
        }
    } except ImportError {}
    return client_dir;
}

impl ViteBundler.create_package_json(
    self: ViteBundler, project_name: Optional[str] = None
) -> Path {
    build_dir = self._get_client_dir();
    build_dir.mkdir(parents=True, exist_ok=True);
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(exist_ok=True);
    package_config = self.config_loader.get_package_config();
    package_json_path = configs_dir / 'package.json';
    name = package_config.get('name', '');
    if (not name and project_name) {
        name = project_name;
    }
    if not name {
        existing_package = self.project_dir / 'package.json';
        if existing_package.exists() {
            try {
                with existing_package.open() as f {
                    existing_data = json.load(f);
                    name = existing_data.get('name', '');
                }
            } except (json.JSONDecodeError, KeyError) {}
        }
    }
    if not name {
        name = self.project_dir.name or 'jac-app';
    }
    dependencies = package_config.get('dependencies', {});
    dev_dependencies = package_config.get('devDependencies', {});

    config_relative = os.path.relpath(configs_dir / 'vite.config.js', self.project_dir);
    scripts = {
        'build': f'vite build --config {config_relative}',
        'dev': f'vite dev --config {config_relative}',
        'preview': f'vite preview --config {config_relative}'
    };
    user_scripts = package_config.get('scripts', {});
    scripts.update(user_scripts);
    package_data = {
        'name': name,
        'version': package_config.get('version', '1.0.0'),
        'description': package_config.get('description', f"Jac application: {name}"),
        'type': 'module',
        'main': 'index.js',
        'scripts': scripts,
        'dependencies': dependencies,
        'devDependencies': dev_dependencies
    };
    for (key, value) in package_config.items() {
        if (
            key
            not in {'name', 'version', 'description', 'dependencies', 'devDependencies'}
        ) {
            package_data[key] = value;
        }
    }
    with package_json_path.open('w', encoding='utf-8') as f {
        json.dump(package_data, f, indent=2);
    }

    self.create_tsconfig();

    self.create_config_files();

    self.create_npmrc();
    return package_json_path;
}

impl ViteBundler.create_tsconfig(self: ViteBundler) -> Path {
    build_dir = self._get_client_dir();
    build_dir.mkdir(parents=True, exist_ok=True);
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(exist_ok=True);
    tsconfig_path = configs_dir / 'tsconfig.json';

    default_compiler_options = {
        'target': 'ES2020',
        'useDefineForClassFields': True,
        'lib': ['ES2020', 'DOM', 'DOM.Iterable'],
        'module': 'ESNext',
        'skipLibCheck': True,
        'moduleResolution': 'bundler',
        'allowImportingTsExtensions': True,
        'resolveJsonModule': True,
        'isolatedModules': True,
        'noEmit': True,
        'jsx': 'react-jsx',
        'strict': True,
        'noUnusedLocals': True,
        'noUnusedParameters': True,
        'noFallthroughCasesInSwitch': True
    };
    default_include = ['components/**/*'];
    default_exclude = ['.jac'];

    user_ts_config = self.config_loader.get_ts_config();
    user_compiler_options = user_ts_config.get('compilerOptions', {});
    user_include = user_ts_config.get('include', []);
    user_exclude = user_ts_config.get('exclude', []);

    merged_compiler_options: dict[str, str | bool | list[str] | dict[str, list[str]]] = {
        ** default_compiler_options,
        ** user_compiler_options
    };

    paths_config = self.config_loader.get_paths_config();
    if paths_config {
        ts_paths: dict[str, list[str]] = {};
        for (alias_pattern, target_path) in paths_config.items() {
            ts_target = target_path.lstrip('./');
            ts_paths[alias_pattern] = [ts_target];
        }
        merged_compiler_options['baseUrl'] = '.';
        merged_compiler_options['paths'] = ts_paths;
    }

    merged_include = user_include or default_include;
    merged_exclude = user_exclude or default_exclude;
    tsconfig_data = {
        'compilerOptions': merged_compiler_options,
        'include': merged_include,
        'exclude': merged_exclude
    };

    tsconfig_path.write_text(json.dumps(tsconfig_data, indent=2), encoding='utf-8');
    return tsconfig_path;
}

impl ViteBundler._format_config_object(
    self: ViteBundler, config: dict[str, any], indent: int = 0
) -> str {
    if not config {
        return '';
    }
    indent_str = ' ' * indent;
    items = [];
    for (key, value) in config.items() {
        if isinstance(value, str) {
            items.append(f"{indent_str}  {key}: '{value}',");
        } elif isinstance(value, bool) {
            items.append(f"{indent_str}  {key}: {str(value).lower()},");
        } elif isinstance(value, (int, float)) {
            items.append(f"{indent_str}  {key}: {value},");
        } elif isinstance(value, list) {
            list_str = ', '.join(repr(v) for v in value);
            items.append(f"{indent_str}  {key}: [{list_str}],");
        } elif isinstance(value, dict) {
            nested = self._format_config_object(value, (indent + 2));
            items.append(f"{indent_str}  {key}: {{{nested}{indent_str}  }},");
        } else {
            items.append(f"{indent_str}  {key}: {repr(value)},");
        }
    }
    return '\n'.join(items);
}

impl ViteBundler._resolve_api_base_url(
    self: ViteBundler, api_base_url_override: str = ""
) -> str {
    api_config_data = self.config_loader.get_api_config();
    toml_base_url = api_config_data.get('base_url', '');
    env_override = os.environ.get(API_BASE_URL_ENV_VAR, '');
    return toml_base_url or api_base_url_override or env_override;
}

def _to_js_expr(value: any) -> str {
    if value is None {
        return "null";
    }

    if isinstance(value, bool) {
        return "true" if value else "false";
    }

    if isinstance(value, (int, float)) {
        return json.dumps(value);
    }

    if value?.isoformat {
        return json.dumps(json.dumps(value.isoformat()));
    }

    if isinstance(value, str) {
        return json.dumps(json.dumps(value));
    }

    try {
        return json.dumps(value);
    } except (TypeError, ValueError) {
        return json.dumps(json.dumps(str(value)));
    }
}

impl ViteBundler._format_define_entries(
    self: ViteBundler, api_base_url: str, custom_defines: dict[str, any]
) -> str {
    entries = [];

    if api_base_url {
        entries.append(f"    '{JAC_API_BASE_URL_KEY}': {_to_js_expr(api_base_url)}");
    }
    for (key, value) in custom_defines.items() {
        entries.append(f"    '{key}': {_to_js_expr(value)}");
    }
    return ',\n'.join(entries);
}

def _proxy_entry(key: str, api_port: int) -> str {
    return (
        f'\n      "{key}": {{'
        f'\n        target: "http://localhost:{api_port}",'
        '\n        changeOrigin: true,'
        '\n      },'
    );
}

def _exact_proxy_key(path: str) -> str {
    import re;
    return '^' + re.escape(path).replace('\\', '\\\\') + '$';
}

impl ViteBundler._generate_vite_config_content(
    self: ViteBundler,
    is_dev: bool,
    entry_file: Path,
    api_base_url: str,
    base_path: str,
    api_port: int = 8000,
    for_desktop_dev: bool = False,
    desktop_broker_port: int = 0,
    api_paths: (list[str] | None) = None,
    client_paths: (list[str] | None) = None
) -> str {
    build_dir = self._get_client_dir();
    project_relative = Path(
        os.path.relpath(self.project_dir, build_dir / 'configs')
    ).as_posix();
    vite_config_data = self.config_loader.get_vite_config();

    try {
        entry_relative = entry_file.relative_to(build_dir).as_posix();
    } except ValueError {
        entry_relative = entry_file.as_posix();
    }

    entry_dir = entry_relative.rpartition('/')[0];
    if is_dev {
        compiled_base = (self._client_app_dir() / 'compiled').relative_to(
            build_dir
        ).as_posix();
    } elif entry_relative.endswith('/build/main.js') {
        compiled_base = entry_relative[:-13] + '/compiled';
    } elif entry_dir.rpartition('/')[2] == 'compiled' {
        compiled_base = entry_dir;
    } else {
        compiled_base = 'compiled';
    }
    compiled_utils_relative = f"{compiled_base}/client_runtime.js";
    compiled_pwa_relative = f"{compiled_base}/pwa_runtime.js";
    compiled_desktop_relative = f"{compiled_base}/desktop_api.js";
    compiled_ui_relative = f"{compiled_base}/client_mobui.js";
    compiled_assets_relative = f"{compiled_base}/assets";

    ui_alias_str = (
        f'\n      "@jac/mobui": path.resolve(buildDir, "{compiled_ui_relative}"),'
    );

    pkg_deps = self.config_loader.get_package_config().get('dependencies', {});
    if 'react-native-web' in pkg_deps {
        ui_alias_str += '\n      "react-native": "react-native-web",';
    }

    pwa_alias_str = '';
    if self.config_loader.is_pwa_enabled() {
        pwa_alias_str = f'\n      "@jac/pwa": path.resolve(buildDir, "{compiled_pwa_relative}"),';
    }

    framework_alias_str = '';
    framework_plugin_import = 'import react from "@vitejs/plugin-react";';
    framework_plugin_call = 'react()';
    try {
        import from jaclang.compiler.backends.es.backends.registry {
            resolve_active_backend
        }
        active_backend = resolve_active_backend();
        for (k, v) in active_backend.vite_aliases().items() {
            framework_alias_str += f'\n      "{k}": "{v}",';
        }
        plugin_lines = active_backend.vite_plugin_lines();
        if plugin_lines is not None {
            (framework_plugin_import, framework_plugin_call) = plugin_lines;
        }
    } except Exception as e {
        console.error(f"[jac warning] Failed to resolve framework backend config: {e}");
    }

    desktop_alias_str = '';
    if os.path.isfile(
        os.path.join(str(self._get_client_dir()), compiled_desktop_relative)
    ) {
        desktop_alias_str = f'\n      "@jac/desktop": path.resolve(buildDir, "{compiled_desktop_relative}"),';
    }

    import from jaclang.client.runtime_source { JAC_VIRTUAL_MODULE_SOURCES }
    virtual_alias_str = '';
    for (module_name, source_name) in JAC_VIRTUAL_MODULE_SOURCES.items() {
        if module_name in ('mobui', 'pwa') {
            continue;
        }
        compiled_relative = f"{compiled_base}/{source_name}.js";
        if os.path.isfile(
            os.path.join(str(self._get_client_dir()), compiled_relative)
        ) {
            virtual_alias_str += f'\n      "@jac/{module_name}": path.resolve(buildDir, "{compiled_relative}"),';
        }
    }
    plugins = [];
    plugin_imports = [];
    plugin_imports.append(framework_plugin_import);
    plugins.append(f'    {framework_plugin_call}');
    lib_imports = vite_config_data.get('lib_imports', []);
    for lib_import in lib_imports {
        if (isinstance(lib_import, str) and lib_import.strip()) {
            plugin_imports.append(lib_import);
        }
    }
    custom_plugins = vite_config_data.get('plugins', []);
    for plugin in custom_plugins {
        if isinstance(plugin, str) {
            plugins.append(f"    {plugin}");
        }
    }
    plugins_str = ',\n'.join(plugins) if plugins else '';
    imports_str = '\n'.join(plugin_imports) if plugin_imports else '';

    extensions = ['.mjs', '.js', '.mts', '.ts', '.jsx', '.tsx', '.json'];
    extensions_str = ', '.join(f'"{ext}"' for ext in extensions);
    build_config = vite_config_data.get('build', {});
    resolve_config = vite_config_data.get('resolve', {});
    resolve_overrides_str = self._format_config_object(resolve_config, indent=6)
        if (isinstance(resolve_config, dict) and resolve_config)
        else '';

    paths_config = self.config_loader.get_paths_config();
    user_aliases_lines: list[str] = [];
    q = '"';
    for (alias_pattern, target_path) in paths_config.items() {
        alias_key = alias_pattern.rstrip('/*');

        target_clean = target_path.lstrip('./').rstrip('/*');
        user_aliases_lines.append(
            f'        {q}{alias_key}{q}: path.resolve(projectRoot, {q}{target_clean}{q}),'
        );
    }
    user_aliases_str = '\n' + '\n'.join(user_aliases_lines)
        if user_aliases_lines
        else '';
    define_config = vite_config_data.get('define', {});
    define_str = self._format_define_entries(api_base_url, define_config);
    imports_section = f"{imports_str}\n" if imports_str else '';
    newline = '\n';
    if is_dev {
        build_overrides_str = self._format_config_object(build_config, indent=2)
            if (isinstance(build_config, dict) and build_config)
            else '';
        server_config = vite_config_data.get('server', {});
        server_config_str = self._format_config_object(server_config, indent=2)
            if (isinstance(server_config, dict) and server_config)
            else '';

        reload_enabled: bool = for_desktop_dev;
        hmr_str = "\n    hmr: { overlay: false }," if reload_enabled else "";
        compiled_reload_plug_in: str = "\n    jacCompiledReload(),"
            if reload_enabled
            else "";
        host_value = '"127.0.0.1"' if for_desktop_dev else 'true';
        claimed = {p for p in (client_paths or [])};
        builtin_proxy_str: str = "";
        for prefix in DEV_PROXY_PREFIXES {
            if prefix in claimed {
                continue;
            }
            builtin_proxy_str += _proxy_entry(prefix, api_port);
        }
        declared_seen: set[str] = set();
        declared_proxy_str: str = "";
        for declared_path in (api_paths or []) {
            if not declared_path.startswith('/') or declared_path == '/' {
                continue;
            }
            if '{' in declared_path {
                key = declared_path.split('{')[0].rstrip('/');
                if not key or key in claimed {
                    continue;
                }
            } else {
                key = _exact_proxy_key(declared_path);
            }
            if key in declared_seen {
                continue;
            }
            declared_seen.add(key);
            declared_proxy_str += _proxy_entry(key, api_port);
        }
        desktop_server_extras: str = "";
        desktop_proxy_str: str = "";
        if for_desktop_dev {
            desktop_server_extras = "\n    strictPort: true,";
            broker_port: int = desktop_broker_port or 8000;
            desktop_proxy_str = (
                f'\n      "/__jac": {{'
                f'\n        target: "http://127.0.0.1:{broker_port}",'
                '\n        changeOrigin: true,'
                '\n      },'
            );
        }

        mobile_compiled_block: str = (
            r'''

// When Jac recompiles, push full-reload to the webview (the desktop shell does not watch project files)
function sendFullReload(server) {
  let sent = false;
  // Broadcast over the websocket first (works for both Vite 5 and Vite 6 clients).
  try {
    if (server.ws && typeof server.ws.send === "function") {
      server.ws.send({ type: "full-reload", path: "*", jacTriggered: true });
      sent = true;
    }
  } catch (e) {}
  // Vite 6 environment fallback for runners that expose environment hot channels.
  try {
    const envs = server.environments;
    if (envs && typeof envs === "object") {
      for (const k of Object.keys(envs)) {
        const env = envs[k];
        if (env && env.hot && typeof env.hot.send === "function") {
          env.hot.send({ type: "full-reload", path: "*", jacTriggered: true });
          sent = true;
        }
      }
    }
  } catch (e) {}
  return sent;
}

function jacCompiledReload() {
  return {
    name: "jac-compiled-reload",
    configureServer(server) {
      const compiled = path.resolve(buildDir, __JAC_COMPILED_DIR__);
      try { server.watcher.add(compiled); } catch (e) {}
      let timer = null;
      const fire = (file) => {
        if (typeof file !== "string") return;
        const norm = file.split(path.sep).join("/");
        if (!norm.includes("/compiled/") || !norm.endsWith(".js")) return;
        if (timer) clearTimeout(timer);
        timer = setTimeout(() => {
          sendFullReload(server);
        }, 300);
      };
      server.watcher.on("change", fire);
      server.watcher.on("add", fire);
    },
    // Intercept hot updates for compiled files and force full-reload instead of module HMR
    handleHotUpdate(ctx) {
      const norm = ctx.file.split(path.sep).join("/");
      if (norm.includes("/compiled/") && norm.endsWith(".js")) {
        sendFullReload(ctx.server);
        return [];
      }
    },
  };
}
'''
                if reload_enabled
                else ""
        );
        mobile_compiled_block = mobile_compiled_block.replace(
            '__JAC_COMPILED_DIR__', json.dumps(compiled_base)
        );
        config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import fs from "fs";
import {{ fileURLToPath }} from "url";
{imports_section}const __dirname = path.dirname(fileURLToPath(import.meta.url));
const buildDir = path.resolve(__dirname, "..");
const projectRoot = path.resolve(__dirname, "{project_relative}");
import jacFastRefresh from "./jac-fast-refresh.js";
import jacClientEvents, {{ recordClientEvent }} from "./jac-client-events.js";

// Vite plugin: hand the browser's RAW error payload to the Jac process.
// No path rewriting, no file derivation, no terminal rendering here: the Jac
// side owns resolving a compiled coordinate back to a .jac location, and it
// is the only place a client failure is printed.
function jacErrorReporter() {{
  const seen = new Map();
  return {{
    name: "jac-error-reporter",
    configureServer(server) {{
      server.ws.on("jac:client-error", (data) => {{
        const key = String(data.type) + ":" + String(data.message);
        const now = Date.now();
        if (seen.get(key) > now - 2000) return;
        seen.set(key, now);
        try {{ recordClientEvent(data); }} catch (e) {{}}
      }});
    }},
  }};
}}

// Vite plugin: write the bound dev-server port for the jac CLI to read
function jacPortReporter() {{
  return {{
    name: "jac-port-reporter",
    configureServer(server) {{
      server.httpServer?.once("listening", () => {{
        const addr = server.httpServer.address();
        if (addr && typeof addr === "object") {{
          fs.writeFileSync(path.resolve(buildDir, ".dev-port"), String(addr.port));
        }}
      }});
    }},
  }};
}}

// Vite plugin: full-reload on demand. Fast Refresh boundaries swallow edits
// that change a module's export set (e.g. removing `:pub`), running stale code
// with no signal. The jac dev server detects the change and bumps
// .jac-force-reload; this reload re-runs the app so the real link error
// surfaces at load (overlay). jacTriggered keeps the dev-status vite slot intact.
function jacForceReload() {{
  const signalFile = path.resolve(buildDir, ".jac-force-reload");
  return {{
    name: "jac-force-reload",
    configureServer(server) {{
      // Create the file so the watch attaches to an existing path; each reload
      // request bumps its contents, firing a "change" the watcher delivers.
      // Reloads fire only when the nonce content actually advances, so a
      // watcher replay of the boot-time value can never cause a spurious reload.
      let lastNonce = "0";
      try {{ fs.writeFileSync(signalFile, lastNonce); }} catch (e) {{}}
      try {{ server.watcher.add(signalFile); }} catch (e) {{}}
      const onSig = (f) => {{
        if (path.resolve(f) !== signalFile) return;
        let nonce;
        try {{ nonce = fs.readFileSync(signalFile, "utf-8"); }} catch (e) {{ return; }}
        if (nonce === lastNonce) return;
        lastNonce = nonce;
        server.ws.send({{ type: "full-reload", path: "*", jacTriggered: true }});
      }};
      server.watcher.on("add", onSig);
      server.watcher.on("change", onSig);
    }},
  }};
}}

// Vite plugin: surface Jac diagnostics via Vite's native error overlay.
// The jac dev server owns .jac-status.json; the file existing means broken
// (show the rendered diagnostic), removed means recovered (reload).
function jacBuildErrorOverlay() {{
  const statusFile = path.resolve(buildDir, ".jac-status.json");
  let lastRaw = null;
  const read = () => {{
    try {{ return fs.readFileSync(statusFile, "utf-8"); }} catch (e) {{ return ""; }}
  }};
  return {{
    name: "jac-build-error-overlay",
    configureServer(server) {{
      const push = (raw) => {{
        if (raw === lastRaw) return;
        // lastRaw is the last KNOWN state, not the last sent one: record it
        // before any skip, or a recovery that happens with zero clients would
        // leave the old error latched here and dedup-suppress an identical
        // error recurring later.
        lastRaw = raw;
        // No live clients: skip the broadcast (Vite would buffer it and replay
        // stale state to the first client; the connection handler replays the
        // CURRENT state instead).
        if (server.ws.clients && server.ws.clients.size === 0) return;
        if (!raw) {{
          server.ws.send({{ type: "full-reload", path: "*", jacTriggered: true }});
          return;
        }}
        // The Jac process already rendered the diagnostic; the overlay shows the
        // headline as the message and the rendered block (location, snippet,
        // help) as the frame.
        let file = "", message = raw, frame = "", stack = "", loc = null;
        try {{
          const data = JSON.parse(raw);
          const all = data.diagnostics || [];
          const diag = all[0] || {{}};
          const more = all.length > 1 ? " (+" + (all.length - 1) + " more)" : "";
          file = diag.file || "";
          message = (diag.code ? diag.code + ": " : "")
            + (diag.message || "Jac build error") + more;
          frame = diag.rendered || "";
          stack = diag.stack || "";
          if (diag.line) loc = {{ file: file, line: diag.line, column: diag.column || 0 }};
        }} catch (e) {{}}
        server.ws.send({{
          type: "error",
          err: {{ message: message, stack: stack, id: file, loc: loc, frame: frame, plugin: "jac" }},
        }});
      }};
      try {{ server.watcher.add(statusFile); }} catch (e) {{}}
      const onWrite = (f) => {{ if (path.resolve(f) === statusFile) push(read()); }};
      server.watcher.on("add", onWrite);
      server.watcher.on("change", onWrite);
      server.watcher.on("unlink", (f) => {{
        const abs = path.resolve(f);
        if (abs === statusFile) {{
          push("");
          return;
        }}
        // A served module was deleted (e.g. its Jac source was removed while
        // still imported). Importers keep a cached transform pointing at the
        // dead file, which 404s into a blank page with no overlay. Invalidate
        // them and reload so the fresh transform surfaces Vite's own
        // "Failed to resolve import" error overlay.
        try {{
          const mods = server.moduleGraph.getModulesByFile(abs);
          if (mods && mods.size) {{
            let hadImporters = false;
            for (const mod of mods) {{
              for (const importer of mod.importers) {{
                hadImporters = true;
                server.moduleGraph.invalidateModule(importer);
              }}
              server.moduleGraph.invalidateModule(mod);
            }}
            if (hadImporters) {{
              server.ws.send({{ type: "full-reload", path: "*", jacTriggered: true }});
            }}
          }}
        }} catch (e) {{}}
      }});
      // A browser opened (or reloaded) while broken gets the overlay immediately
      server.ws.on("connection", () => {{
        const raw = read();
        if (raw) {{ lastRaw = null; push(raw); }}
      }});
    }},
  }};
}}
{mobile_compiled_block}
/**
 * Vite DEV configuration for HMR mode
 * Proxies API routes to Python server at localhost:{api_port}
 */
export default defineConfig({{
  base: "{base_path}",
  define: {{
{define_str}
  }},
  plugins: [
    jacErrorReporter(),
    jacPortReporter(),
    jacBuildErrorOverlay(),
    jacClientEvents(),
    jacForceReload(),
    jacFastRefresh(),{compiled_reload_plug_in}{(
            newline + plugins_str + newline + '  '
        )
            if plugins_str
            else ''}],
  root: buildDir,
  envDir: projectRoot, // Load .env files from project root
  publicDir: false,
  appType: 'spa',
  build: {{
    sourcemap: true, // Enable source maps for better error messages{build_overrides_str}
  }},
  server: {{
    host: {host_value},
    watch: {{
      usePolling: true,
      interval: 100,
      // Runtime state (the desktop SQLite anchor store lives under
      // <root>/.jac/data/ and mutates on every DB write, WAL/SHM included)
      // must not retrigger HMR, or a --dev app that touches its DB reloads
      // in a loop.
      ignored: [
        "**/.jac/data/**",
        "**/*.sqlite",
        "**/*.sqlite3",
        "**/*.db",
        "**/*.db-wal",
        "**/*.db-shm",
      ],
    }},
    proxy: {{{builtin_proxy_str}{declared_proxy_str}{desktop_proxy_str}
    }},
{server_config_str}{hmr_str}{desktop_server_extras}
  }},
  resolve: {{
    alias: {{
      "@jac/runtime": path.resolve(buildDir, "{compiled_utils_relative}"),{pwa_alias_str}{desktop_alias_str}{virtual_alias_str}{framework_alias_str}{ui_alias_str}
      "@jac-client/assets": path.resolve(buildDir, "{compiled_assets_relative}"),{user_aliases_str}
    }},
    extensions: [{extensions_str}],
{resolve_overrides_str}
  }},
}});
''';
    } else {
        build_overrides_str = self._format_config_object(build_config, indent=2)
            if (isinstance(build_config, dict) and build_config)
            else '';
        server_config = vite_config_data.get('server', {});
        server_config_str = self._format_config_object(server_config, indent=2)
            if (isinstance(server_config, dict) and server_config)
            else '';
        server_section = f"  server: {{{newline}{server_config_str}{newline}  }},{newline}"
            if server_config_str
            else '';
        try {
            output_relative = self.output_dir.relative_to(build_dir).as_posix();
        } except ValueError {
            output_relative = self.output_dir.as_posix();
        }
        config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import fs from "fs";
import {{ fileURLToPath }} from "url";
{imports_section}const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Resolve this configuration relative to its exported workspace.
const buildDir = path.resolve(__dirname, "..");
const projectRoot = path.resolve(__dirname, "{project_relative}");

// Jac source mapper plugin - chains the per-file column maps the Jac client
// compiler writes, so a bundled stack keeps its way back to .jac coordinates.
// It derives no locations of its own: that is the Jac side's job.
function jacSourceMapChain() {{
  return {{
    name: 'jac-source-map-chain',
    enforce: 'pre',

    transform(code, id) {{
      if (id.includes('/compiled/') && id.endsWith('.js')) {{
        const mapPath = id + '.map';
        try {{
          if (fs.existsSync(mapPath)) {{
            const rawMap = JSON.parse(fs.readFileSync(mapPath, 'utf-8'));
            return {{ code, map: rawMap }};
          }}
        }} catch (e) {{}}
      }}
      return null;
    }}
  }};
}}

/**
 * Vite configuration generated from config.json (in project root)
 * To customize, edit config.json instead of this file.
 */

export default defineConfig({{
  base: "{base_path}",
  define: {{
{define_str}
  }},
  plugins: [
    jacSourceMapChain(),{(newline + plugins_str + newline + '  ')
            if plugins_str
            else ''}],
  root: buildDir, // base folder (.jac/client/) so vite can find node_modules
  envDir: projectRoot, // Load .env files from project root
    build: {{
    sourcemap: true, // Enable source maps for better error messages
{build_overrides_str}
    rollupOptions: {{
      input: path.resolve(buildDir, "{entry_relative}"), // your compiled entry file
      output: {{
        entryFileNames: "client.[hash].js", // name of the final js file
        assetFileNames: (assetInfo) => assetInfo.name?.endsWith('.css') ? 'styles.css' : '[name].[ext]',
        sourcemapPathTransform: (relativeSourcePath) => {{
          // Transform source map paths to point to original location
          return relativeSourcePath;
        }},
      }},
    }},
    outDir: path.resolve(buildDir, "{output_relative}"), // final bundled output
    emptyOutDir: true,
  }},
  publicDir: false,
{server_section}  resolve: {{
      alias: {{
        "@jac/runtime": path.resolve(buildDir, "{compiled_utils_relative}"),{pwa_alias_str}{desktop_alias_str}{virtual_alias_str}{framework_alias_str}{ui_alias_str}
        "@jac-client/assets": path.resolve(buildDir, "{compiled_assets_relative}"),{user_aliases_str}
      }},
      extensions: [{extensions_str}],
{resolve_overrides_str}
  }},
}});
''';
    }
    return config_content;
}

impl ViteBundler.create_vite_config(
    self: ViteBundler,
    entry_file: Path,
    api_base_url_override: str = "",
    is_dev: bool = False,
    api_port: int = 8000,
    for_desktop_dev: bool = False,
    desktop_broker_port: int = 0,
    api_paths: (list[str] | None) = None,
    client_paths: (list[str] | None) = None
) -> Path {
    build_dir = self._get_client_dir();
    build_dir.mkdir(parents=True, exist_ok=True);
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(exist_ok=True);
    api_base_url = self._resolve_api_base_url(api_base_url_override);
    config_filename = 'vite.dev.config.js' if is_dev else 'vite.config.js';
    config_path = configs_dir / config_filename;
    base_path = self.config_loader.get_base_path();
    config_content = self._generate_vite_config_content(
        is_dev=is_dev,
        entry_file=entry_file,
        api_base_url=api_base_url,
        base_path=base_path,
        api_port=api_port,
        for_desktop_dev=for_desktop_dev,
        desktop_broker_port=desktop_broker_port,
        api_paths=api_paths,
        client_paths=client_paths
    );
    config_path.write_text(config_content, encoding='utf-8');
    if is_dev {
        self._write_fast_refresh_plugin(configs_dir);
        self._write_client_events_plugin(configs_dir);
    }
    return config_path;
}

impl ViteBundler.create_config_files(self: ViteBundler) -> list[Path] {
    configs = self.config_loader.get_configs();
    if not configs {
        return [];
    }
    build_dir = self._get_client_dir();
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(parents=True, exist_ok=True);
    created_files: list[Path] = [];
    for (config_name, config_data) in configs.items() {
        if not isinstance(config_data, dict) {
            continue;
        }
        extension = config_data.get('extension', '.js');
        config_path = configs_dir / f'{config_name}.config{extension}';

        if 'raw' in config_data {
            file_content = _toml_config_from_raw(config_data);
        } else {
            file_content = _toml_config_to_js(config_data);
        }
        config_path.write_text(file_content, encoding='utf-8');
        created_files.append(config_path);
    }
    return created_files;
}

impl ViteBundler.create_npmrc(self: ViteBundler) -> Optional[Path] {
    npm_config = self.config_loader.get_npm_config();
    if not npm_config {
        return None;
    }
    build_dir = self._get_client_dir();
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(parents=True, exist_ok=True);
    npmrc_path = configs_dir / '.npmrc';
    lines: list[str] = [];

    known_keys = {'scoped_registries', 'auth', 'settings'};
    settings = npm_config.get('settings', {});
    for (key, value) in settings.items() {
        if isinstance(value, bool) {
            lines.append(f"{key}={str(value).lower()}");
        } else {
            lines.append(f"{key}={value}");
        }
    }

    scoped_registries = npm_config.get('scoped_registries', {});
    for (scope, registry_url) in scoped_registries.items() {
        lines.append(f"{scope}:registry={registry_url}");
    }

    auth = npm_config.get('auth', {});
    for (registry_path, auth_data) in auth.items() {
        if isinstance(auth_data, dict) {
            for (key, value) in auth_data.items() {
                lines.append(f"{registry_path}:{key}={value}");
            }
        } elif isinstance(auth_data, str) {
            lines.append(f"{registry_path}={auth_data}");
        }
    }
    if not lines {
        return None;
    }
    npmrc_path.write_text('\n'.join(lines) + '\n', encoding='utf-8');
    return npmrc_path;
}

def _toml_config_to_js(config_data: dict[str, any]) -> str {
    return f"module.exports = {json.dumps(
        {
            k: v
            for (k, v) in config_data.items()
            if k not in CONFIG_META_KEYS
        },
        indent=2
    )};\n";
}

def _toml_config_from_raw(config_data: dict[str, any]) -> str {
    content = str(config_data.get('raw', '')).strip();
    return content + '\n' if content else '';
}
