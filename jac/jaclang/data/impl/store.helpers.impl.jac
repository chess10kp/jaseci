glob _SCHEMA_SQL = [
         """
    CREATE TABLE IF NOT EXISTS anchors (
        id             uuid PRIMARY KEY,
        kind           text NOT NULL,
        arch_type      text NOT NULL DEFAULT '',
        arch_module    text NOT NULL DEFAULT '',
        fingerprint    text NOT NULL DEFAULT '',
        root_id        uuid,
        src            uuid,
        dst            uuid,
        undirected     boolean NOT NULL DEFAULT false,
        props          jsonb NOT NULL DEFAULT '{}'::jsonb,
        format_version integer NOT NULL DEFAULT 1,
        version        bigint NOT NULL DEFAULT 0,
        updated_at     timestamptz NOT NULL DEFAULT now(),
        seq            bigserial
    )
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_anchors_src
        ON anchors (src, arch_type) WHERE src IS NOT NULL
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_anchors_dst
        ON anchors (dst, arch_type) WHERE dst IS NOT NULL
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_anchors_kind_type
        ON anchors (kind, arch_type)
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_anchors_root
        ON anchors (root_id) WHERE root_id IS NOT NULL
    """,
         """
    CREATE TABLE IF NOT EXISTS graph_types (
        type_name text NOT NULL,
        ancestor  text NOT NULL,
        PRIMARY KEY (type_name, ancestor)
    )
    """,
         """
    CREATE TABLE IF NOT EXISTS kv_state (
        key        text PRIMARY KEY,
        value      text NOT NULL,
        expires_at timestamptz,
        updated_at timestamptz NOT NULL DEFAULT now()
    )
    """,
         """
    CREATE TABLE IF NOT EXISTS quarantine (
        missing_id  uuid NOT NULL,
        referrer_id uuid,
        kind        text NOT NULL,
        created_at  timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (missing_id, kind)
    )
    """
     ];

impl ConnInfo.dsn -> str {
    if self.unix_socket_dir {
        return (
            f"host={self.unix_socket_dir} user={self.user} " f"dbname={self.database}"
        );
    }
    return (
        f"host={self.host} port={self.port} user={self.user} " f"dbname={self.database}"
    );
}

def _jsonable(o: object) -> str {
    return str(o);
}

def _sanitize_ident(name: str) -> str {
    out = '';
    for ch in name.lower() {
        out += ch if (ch.isalnum() or ch == '_') else '_';
    }
    return out;
}

def _store_ns(info: ConnInfo) -> str {
    return f"{info.unix_socket_dir or info.host}:{info.port}/{info.database}";
}

glob _PG_CHANNEL_LIMIT = 63,
     _CHANNEL_DIGEST_LEN = 16,
     _CHANNEL_ENVELOPE_KEY = '__jac_channel',
     _CHANNEL_ENVELOPE_VERSION = 1,
     _LISTEN_POLL_SECONDS = 1.0,
     _LISTEN_JOIN_SECONDS = 5.0;

def _channel_travels_verbatim(channel: str) -> bool {
    return (
        bool(channel)
        and '\x00' not in channel
        and len(channel.encode('utf-8')) <= _PG_CHANNEL_LIMIT
    );
}

def _channel_ident(channel: str) -> str {
    if _channel_travels_verbatim(channel) {
        return channel;
    }
    import hashlib;
    digest = hashlib.sha256(channel.encode('utf-8')).hexdigest()[:_CHANNEL_DIGEST_LEN];
    stem = _sanitize_ident(channel)[:_PG_CHANNEL_LIMIT - _CHANNEL_DIGEST_LEN - 1];
    return f"{stem}_{digest}";
}

def _quote_channel(ident: str) -> str {
    escaped = ident.replace('"', '""');
    return f'"{escaped}"';
}

def _channel_wire_payload(channel: str, ident: str, payload: str) -> str {
    if ident == channel {
        return payload;
    }
    return json.dumps(
        {
            _CHANNEL_ENVELOPE_KEY: _CHANNEL_ENVELOPE_VERSION,
            'channel': channel,
            'payload': payload
        }
    );
}

def _channel_envelope(payload: str) -> (ChannelMessage | None) {
    try {
        data = json.loads(payload);
    } except Exception {
        return None;
    }
    if not isinstance(data, dict)
        or data.get(_CHANNEL_ENVELOPE_KEY) != _CHANNEL_ENVELOPE_VERSION {
        return None;
    }
    return ChannelMessage(
        channel=str(data.get('channel', '')), payload=str(data.get('payload', ''))
    );
}

def _app_identity -> str {
    import sys;
    cmd = 'embedded';
    try {
        argv = list(sys?.argv or []);
        if argv {
            cmd = os.path.basename(str(argv[0]) or '') or 'embedded';
            if cmd.startswith('jac') and len(argv) > 1 {
                sub = str(argv[1]);
                if sub and not sub.startswith('-') {
                    cmd = sub;
                }
            }
        }
    } except Exception {
        cmd = 'unknown';
    }
    return f"jac:{os.getpid()}:{cmd}"[:63];
}

glob _SCHEMA_LOCK_TAG = 'jac:ensure_schema',
     _SCHEMA_LOCK_WAIT_SECONDS = 30.0,
     _SCHEMA_LOCK_POLL_SECONDS = 0.05,
     _SCHEMA_LOCK_POLL_MAX_SECONDS = 0.5,
     _CONCURRENT_CREATE_STATES = ('23505', '42P07', '42710');

def _schema_lock_key -> int {
    import hashlib;
    digest = hashlib.sha256(_SCHEMA_LOCK_TAG.encode('utf-8')).digest()[:8];
    return int.from_bytes(digest, 'big', signed=True);
}

def _sqlstate(e: Exception) -> str {
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict) and 'C' in arg {
            return str(arg.get('C') or '');
        }
    }
    return '';
}

def _parse_pid(raw: str) -> (int | None) {
    try {
        return int(raw);
    } except ValueError {
        return None;
    }
}

def _owner_alive(pid: (int | None)) -> bool {
    if pid is None or pid <= 0 {
        return True;
    }
    try {
        os.kill(pid, 0);
        return True;
    } except ProcessLookupError {
        return False;
    } except Exception {
        return True;
    }
}

def _park_conn(info: any, conn: any, in_txn: bool, listened: bool) -> None {
    import from jaclang.data.pgpool { pool_enabled, release }
    if conn is None {
        return;
    }
    if not pool_enabled() or getattr(conn, '_closed', False) {
        try {
            conn.close();
        } except Exception {}
        return;
    }
    try {
        if in_txn {
            conn.run('ROLLBACK');
        }
        conn.run('DISCARD ALL');
        if listened {
            conn.notifications.clear();
        }
    } except Exception {
        try {
            conn.close();
        } except Exception {}
        return;
    }
    release(info, conn);
}

def _conn_dead(e: Exception) -> bool {
    if isinstance(e, (ConnectionError, BrokenPipeError, EOFError, OSError)) {
        return True;
    }
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict)
            and arg.get('C') in ('08006', '08003', '57P01', '57P03', '25P03') {
            return True;
        }
    }
    return False;
}
