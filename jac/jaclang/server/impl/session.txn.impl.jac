impl Session.commit(anchor: (Anchor | None) = None) -> None {
    with self._lock {
        if self.store is not None {
            attempt = 0;
            while True {
                try {
                    self.flush(full=True);
                    self.store.commit();
                    break;
                } except Exception as e {
                    if not _is_serialization_conflict(e) or attempt >= MAX_RETRIES {
                        raise;
                    }
                    attempt += 1;
                    self._recover_conflict();
                }
            }
            self._txn_changed.clear();
        } else {
            self._dirty.clear();
            self._deleted.clear();
        }
    }
    self._fire_on_commit();
}

impl Session.abort -> None {
    if self.store is not None {
        self.store.rollback();
    }
    self._evict_uncommitted();
    self._dirty.clear();
    self._deleted.clear();
    self._drop_snapshot_reads();
    self._on_commit = [];
}

impl Session._evict_uncommitted -> None {
    import from jaclang.data.serializer { Serializer }
    for (id, anchor) in list(self.__mem__.items()) {
        if not anchor.persistent or not anchor.is_populated() {
            continue;
        }
        known = self._flushed_hash.get(id);
        dirty = known is None;
        if not dirty {
            try {
                dirty = Serializer._compute_hash(anchor) != known;
            } except Exception {
                dirty = True;
            }
        }
        if dirty {
            if isinstance(anchor, EdgeAnchor) {
                import from jaclang.runtime.osp_graph_sv { sv_forget_edge }
                sv_forget_edge(anchor, self);
            }
            self.__mem__.pop(id, None);
            self._flushed_hash.pop(id, None);
        }
    }
}

impl Session._txn_isolation -> TxnIsolation {
    if self._dirty or self._deleted {
        return TxnIsolation.SERIALIZABLE;
    }
    if self._read_scopes > 0 and self._active_units == 0 {
        return TxnIsolation.SNAPSHOT_READ_ONLY;
    }
    if self._active_units > 0 and self._ro_units == self._active_units {
        return TxnIsolation.SNAPSHOT_READ_ONLY;
    }
    return TxnIsolation.SERIALIZABLE;
}

impl Session._register_ro_writers -> str {
    keys = [
        key
        for (key, ro) in self._unit_stack
        if ro and key is not None
    ];
    for key in keys {
        record_unit_writes(key);
    }
    self._ro_units = 0;
    self._unit_stack = [(key, False) for (key, _ro) in self._unit_stack];
    return keys[-1] if keys else '';
}

impl Session._raise_ro_retry -> None {
    import from uuid { UUID as _UUID }
    last = self._register_ro_writers();
    if self.store is not None {
        try {
            self.store.rollback();
        } except Exception {}
    }
    raise ReadOnlyRetry(anchor_id=_UUID(int=0), unit_key=last);
}

impl Session._drop_snapshot_reads -> None {
    import from jaclang.runtime.osp_graph_sv { sv_forget_edge }
    for id in self._snapshot_reads {
        if id in self._dirty or id in self._deleted {
            continue;
        }
        stale = self.__mem__.pop(id, None);
        self._flushed_hash.pop(id, None);
        if isinstance(stale, EdgeAnchor) {
            sv_forget_edge(stale, self);
        }
    }
    self._snapshot_reads.clear();
}

impl Session._ensure_txn -> None {
    with self._lock {
        if self.store is None {
            return;
        }
        wanted = self._txn_isolation();
        if not self.store.in_txn() {
            self.store.begin(wanted);
            return;
        }
        if wanted is TxnIsolation.SERIALIZABLE
            and self.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY {
            if self._ro_units > 0 {
                self._raise_ro_retry();
            }
            self.store.commit();
            self._drop_snapshot_reads();
            self.store.begin(TxnIsolation.SERIALIZABLE);
        }
    }
}

impl Session.unit_enter(key: (str | None) = None) -> None {
    with self._lock {
        ro = key is not None and ro_units_enabled() and not unit_writes_recorded(key);
        self._active_units += 1;
        if ro {
            self._ro_units += 1;
        }
        self._unit_stack.append((key, ro));
        if self.store is not None and self.store.in_txn() {
            self._ensure_txn();
        }
    }
}

impl Session.read_scope_enter -> None {
    with self._lock {
        self._read_scopes += 1;
    }
}

impl Session.read_scope_exit -> None {
    with self._lock {
        self._read_scopes = max(0, self._read_scopes - 1);
        if self._read_scopes > 0 or self.store is None {
            return;
        }
        if self.store.txn_isolation() is not TxnIsolation.SNAPSHOT_READ_ONLY {
            return;
        }
        try {
            self.store.commit();
        } except Exception as e {
            logger.warning(
                f"read snapshot close failed; rolling back: {type(e).__name__}: {e}"
            );
            try {
                self.store.rollback();
            } except Exception {}
        }
        self._drop_snapshot_reads();
    }
}

impl Session.unit_exit -> None {
    with self._lock {
        self._active_units = max(0, self._active_units - 1);
        try {
            if self._active_units > 0 {
                return;
            }
            if self.store is None or not self.store.in_txn() {
                return;
            }
            try {
                self.commit();
            } except WriteConflict {
                try {
                    self.store.rollback();
                } except Exception {}
                raise;
            } except Exception as e {
                logger.warning(
                    f"unit close commit failed; rolling back: {type(e).__name__}: {e}"
                );
                try {
                    self.store.rollback();
                } except Exception {}
            }
        } finally {
            if self._unit_stack {
                (_key, was_ro) = self._unit_stack.pop();
                if was_ro {
                    self._ro_units = max(0, self._ro_units - 1);
                }
            }
        }
    }
}

impl Session.unit_depth -> int {
    return self._active_units;
}

impl Session.reset_fetch_count -> None {
    self._fetch_count = 0;
}

impl Session.get_fetch_count -> int {
    return self._fetch_count;
}

impl Session._recover_conflict -> None {
    if self.store is not None {
        try {
            self.store.rollback();
        } except Exception {}
    }
    for id in list(self._txn_changed) {
        if id in self.__mem__ {
            self._flushed_hash.pop(id, None);
            self._dirty[id] = None;
        } else {
            self._deleted.add(id);
        }
    }
}

impl Session.read_barrier -> None {
    if self.store is None {
        return;
    }
    try {
        self._ensure_txn();
        self.flush();
    } except Exception as e {
        if not _is_serialization_conflict(e) {
            raise;
        }
        self._recover_conflict();
        self._ensure_txn();
        self.flush();
    }
}

impl Session.ensure_writable_txn -> None {
    with self._lock {
        if self.store is None {
            return;
        }
        if self.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY {
            if self._ro_units > 0 {
                self._raise_ro_retry();
            }
            self.store.commit();
            self._drop_snapshot_reads();
            self.store.begin(TxnIsolation.SERIALIZABLE);
        } elif not self.store.in_txn() {
            self.store.begin(TxnIsolation.SERIALIZABLE);
        }
    }
}

impl Session.run_request(body: Callable) -> any {
    attempt = 0;
    while True {
        try {
            result = body();
            self.commit();
            return result;
        } except Exception as e {
            if (
                self.store is not None
                and _is_serialization_conflict(e)
                and attempt < MAX_RETRIES
            ) {
                attempt += 1;
                logger.info(
                    f"serialization conflict; re-running request "
                    f"(attempt {attempt}/{MAX_RETRIES})"
                );
                self.abort();
                continue;
            }
            self.abort();
            raise;
        }
    }
}

impl Session.close -> None {
    try {
        self.commit();
    } except Exception as e {
        logger.warning(f"commit on close failed: {type(e).__name__}: {e}");
    }
    if self.store is not None {
        self.store.close();
    }
    self.__mem__.clear();
    self._dirty.clear();
    self._deleted.clear();
    self._flushed_hash.clear();
    import from jaclang.runtime.osp_graph_sv { sv_store_closed }
    sv_store_closed(self);
}
