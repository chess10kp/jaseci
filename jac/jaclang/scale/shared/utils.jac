import from urllib.parse { urlparse }
import from jaclang.server.transport { TransportResponse, Meta }

glob _LOOPBACK_HOSTS: set[str] = {'127.0.0.1', 'localhost', '::1'};

def is_safe_loopback_redirect(url: str | None) -> bool {
    if not url {
        return False;
    }
    try {
        parsed = urlparse(url);
    } except Exception {
        return False;
    }
    if parsed.scheme not in ('http', 'https') {
        return False;
    }

    host = parsed.hostname;
    return host in _LOOPBACK_HOSTS;
}

def extract_bearer_token(authorization: str | None, user_manager: any) -> str | None {
    token: (str | None) = None;
    if (
        authorization
        and isinstance(authorization, str)
        and authorization.startswith('Bearer ')
    ) {
        token = authorization[7:];
    }
    return user_manager.validate_jwt_token(token) if token else None;
}
