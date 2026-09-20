impl PgStore.notify(channel: str, payload: str) -> None {
    with self._lock {
        ident = _channel_ident(channel);
        conn: any = self._side();
        conn.run(
            'SELECT pg_notify(:c, :p)',
            c=ident,
            p=_channel_wire_payload(channel, ident, payload)
        );
    }
}

impl PgStore.listen(channel: str, callback: any) -> None {
    with self._lock {
        ident = _channel_ident(channel);
        self._listeners.append(
            ChannelListener(channel=channel, ident=ident, callback=callback)
        );
        conn: any = self._side();
        conn.run(f"LISTEN {_quote_channel(ident)}");
        self._side_listened = True;
        if self._listen_thread is None {
            self._listen_stop = threading.Event();
            t: any = threading.Thread(
                target=self._listen_loop, daemon=True, name='jac-pg-listen'
            );
            self._listen_thread = t;
            t.start();
        }
    }
}

impl PgStore.unlisten(channel: str) -> None {
    parked: any = None;
    with self._lock {
        ident = _channel_ident(channel);
        kept = [
            lst
            for lst in self._listeners
            if lst.channel != channel
        ];
        if len(kept) == len(self._listeners) {
            return;
        }
        self._listeners = kept;
        shared = any((lst.ident == ident) for lst in kept);
        conn: any = self._side_conn;
        if conn is not None and not shared {
            try {
                conn.run(f"UNLISTEN {_quote_channel(ident)}");
            } except Exception as e {
                logger.debug(f"unlisten {channel} failed: {e}");
            }
        }
        if not self._listeners {
            parked = self._stop_listen_thread();
        }
    }
    self._join_listen_thread(parked);
}

impl PgStore._stop_listen_thread -> any {
    if self._listen_stop is not None {
        self._listen_stop.set();
    }
    parked = self._listen_thread;
    self._listen_thread = None;
    return parked;
}

impl PgStore._join_listen_thread(parked: any) -> None {
    if parked is None or parked is threading.current_thread() {
        return;
    }
    parked.join(timeout=_LISTEN_JOIN_SECONDS);
    if parked.is_alive() {
        logger.warning('pg listen thread did not stop within its join window');
    }
}

impl PgStore._listen_loop -> None {
    import select;
    stop: any = self._listen_stop;
    if stop is None {
        return;
    }
    while not stop.is_set() {
        pending: list[tuple[int, str, str]] = [];
        sock: any = None;
        try {
            with self._lock {
                conn: any = self._side_conn;
                if conn is None {
                    break;
                }
                if conn.notifications {
                    pending = list(conn.notifications);
                    conn.notifications.clear();
                } else {
                    sock = conn._sock;
                }
            }
            if not pending {
                if sock is None {
                    stop.`wait(_LISTEN_POLL_SECONDS);
                    continue;
                }
                readable = select.select([sock], [], [], _LISTEN_POLL_SECONDS)[0];
                if stop.is_set() {
                    break;
                }
                if not readable {
                    continue;
                }
                with self._lock {
                    conn2: any = self._side_conn;
                    if conn2 is None {
                        break;
                    }
                    conn2.run('SELECT 1');
                    pending = list(conn2.notifications);
                    conn2.notifications.clear();
                }
            }
            for (pid, channel, payload) in pending {
                self._dispatch_notification(channel, payload);
            }
        } except Exception as e {
            logger.debug(f"listen loop hiccup: {e}");
            stop.`wait(_LISTEN_POLL_SECONDS);
        }
    }
}

impl PgStore._dispatch_notification(channel: str, payload: str) -> None {
    envelope: (ChannelMessage | None) = None;
    decoded = False;
    for lst in list(self._listeners) {
        if lst.ident != channel {
            continue;
        }
        body = payload;
        if lst.channel != channel {
            if not decoded {
                envelope = _channel_envelope(payload);
                decoded = True;
                if envelope is None {
                    logger.warning(
                        f"notification on {channel} carries no channel envelope;"
                        ' dropping it rather than guessing a subscriber'
                    );
                }
            }
            if envelope is None or envelope.channel != lst.channel {
                continue;
            }
            body = envelope.payload;
        }
        try {
            lst.callback(body);
        } except Exception as e {
            logger.warning(f"listener callback failed: {e}");
        }
    }
}
