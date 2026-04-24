"""Resolve dev-server host for Capacitor live reload (LAN, emulator, USB/adb)."""
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

"""Pick the host string the device/emulator uses to reach the dev PC."""
def resolve_mobile_dev_host(reach: str, plat: str, host_override: str = "") -> str {
    if host_override and host_override.strip() {
        return host_override.strip();
    }
    r = reach.lower().strip() if reach else "auto";
    if r == "" {
        r = "auto";
    }
    p = plat.lower().strip();
    if r == "usb" {
        if p == "ios" {
            raise ValueError(
                "Reach mode 'usb' is not supported for iOS in this version. "
                "Use --mobile-reach lan with your Mac's LAN IP, or iOS Simulator with --mobile-reach emulator."
            );
        }
        return "127.0.0.1";
    }
    if r == "emulator" {
        if p == "android" {
            return "10.0.2.2";
        }
        return "127.0.0.1";
    }
    if r == "lan" {
        ip = detect_lan_ipv4();
        if not ip {
            raise RuntimeError(
                "Could not detect a LAN IPv4 address. "
                "Set --mobile-host explicitly or fix network connectivity."
            );
        }
        return ip;
    }
    # auto
    ip = detect_lan_ipv4();
    if ip {
        return ip;
    }
    return "127.0.0.1";
}
