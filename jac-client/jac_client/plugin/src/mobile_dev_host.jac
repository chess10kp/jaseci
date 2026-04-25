"""Resolve dev-server host for Capacitor live reload."""
import socket;

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
