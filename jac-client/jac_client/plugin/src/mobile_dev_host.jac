"""Resolve dev-server host for Capacitor live reload."""
import os;
import socket;
import from pathlib { Path }
import from jac_client.plugin.src.config_loader { JacClientConfig }

glob JAC_MOBILE_VITE_PORT_ENV: str = "JAC_MOBILE_VITE_PORT";

"""Best-effort LAN IPv4 of this machine (connects outbound to discover primary route)."""
def detect_lan_ipv4 -> str | None {
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM);
    try {
        s.settimeout(0.5);
        s.connect(("8.8.8.8", 80));
        addr = s.getsockname()[0];
        if addr and addr != "127.0.0.1" {
            return addr;
        }
    } except OSError {
        ;
    } finally {
        s.close();
    }
    return None;
}

"""Resolve backend API port from jac.toml base_url or CLI default."""
def resolve_mobile_server_port(toml_base_url: str, api_port: int) -> int {
    if toml_base_url {
        import from urllib.parse { urlparse }

        parsed = urlparse(toml_base_url);
        return parsed.port or api_port;
    }
    return api_port;
}

"""Vite HMR port for mobile dev: JAC_MOBILE_VITE_PORT, then [plugins.client].vite.server.port, else `cli_vite_port`
(same as core `jac start --dev --port`, default 8000)."""
def resolve_mobile_vite_port(project_dir: Path, cli_vite_port: int = 8000) -> int {
    raw = os.environ.get(JAC_MOBILE_VITE_PORT_ENV, "");
    if raw and str(raw).strip() {
        return int(str(raw).strip());
    }
    loader = JacClientConfig(project_dir);
    vite_cfg = loader.get_vite_config();
    if not vite_cfg {
        return cli_vite_port;
    }
    server = vite_cfg.get("server", None);
    if not isinstance(server, dict) {
        return cli_vite_port;
    }
    p = server.get("port", None);
    if p is not None and str(p).strip() {
        return int(p);
    }
    return cli_vite_port;
}

"""Pick the host string the mobile runtime uses to reach the dev machine."""
def resolve_mobile_dev_host(plat: str, host_override: str = "") -> str {
    if host_override and host_override.strip() {
        return host_override.strip();
    }
    p = plat.lower().strip();
    if p not in ["android", "ios"] {
        p = "android";
    }
    # Prefer a LAN IP when available so physical devices work out of the box.
    ip = detect_lan_ipv4();
    if ip {
        return ip;
    }
    # Fallback for simulators/emulators and offline environments.
    return "127.0.0.1";
}
