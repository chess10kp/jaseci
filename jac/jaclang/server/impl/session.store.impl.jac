impl Session.postinit -> None {
    self._init_memory();
    self._fetch_count = 0;
    self._flushed_hash = {};
    self._txn_changed = set();
    self._runtime = None;
    self._active_units = 0;
    self._flushing = None;
    self._read_scopes = 0;
    self._ro_units = 0;
    self._unit_stack = [];
    self._snapshot_reads = set();
    self._version_seen = {};
    if self.store is None and self.base_path {
        url = os.environ.get('JAC_DB_URL', '');
        promos = promotions_for(self.base_path);
        if url {
            self.store = PgStore(
                conninfo=conninfo_from_url(url), promotions=promos, auto_schema=True
            );
        } else {
            lease = runtime_for_base(self.base_path, self.target_path);
            self._runtime = lease.runtime;
            pgs = PgStore(
                conninfo=lease.runtime.conninfo(),
                ensure_cb=lease.runtime.ensure,
                promotions=promos,
                auto_schema=True
            );
            if lease.reset {
                if lease.runtime.is_running() {
                    pgs.reset_data();
                } else {
                    pgs.pending_reset = True;
                }
            }
            self.store = pgs;
        }
    }
}

impl Session.data_location -> (str | None) {
    rt: any = self._runtime;
    if rt is not None {
        return f"{rt.data_dir}/{rt.database}";
    }
    if isinstance(self.store, PgStore) {
        info = self.store.conninfo;
        return info.unix_socket_dir or f"{info.host}:{info.port}/{info.database}";
    }
    return None;
}

impl Session.get(id: UUID) -> (Anchor | None) {
    if id in self._deleted {
        return None;
    }
    if (hit := self.__mem__.get(id)) is not None {
        return hit;
    }
    if self.store is None {
        return None;
    }
    return self.batch_get([id]).get(id);
}

impl Session.delete(id: UUID) -> None {
    with self._lock {
        self.__mem__.pop(id, None);
        self._dirty.pop(id, None);
        self._flushed_hash.pop(id, None);
        self._deleted.add(id);
    }
}

impl Session.`has(id: UUID) -> bool {
    if id in self._deleted {
        return False;
    }
    if id in self.__mem__ {
        return True;
    }
    if self.store is None {
        return False;
    }
    try {
        self.read_barrier();
        return id in self.store.existing([id]);
    } except Exception as e {
        if not _is_serialization_conflict(e) {
            raise;
        }
        self._recover_conflict();
        self.read_barrier();
        return id in self.store.existing([id]);
    }
}

impl Session.get_roots -> Generator[Root, None, None] {
    seen: set[UUID] = set();
    for anchor in list(self.__mem__.values()) {
        if isinstance(anchor.archetype, Root) {
            seen.add(anchor.ensure_id());
            yield anchor.archetype;
        }
    }
    if self.store is not None {
        self.read_barrier();
        remote = [
            i
            for i in self.store.root_ids()
            if i not in seen and i not in self._deleted
        ];
        root_rows = self.store.load_full(remote);
        for (rid, row) in root_rows.items() {
            anchor = self._materialize(row);
            if anchor is not None and isinstance(anchor.archetype, Root) {
                yield anchor.archetype;
            }
        }
    }
}

impl Session.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    out: dict[UUID, Anchor] = {};
    missing: list[UUID] = [];
    for i in ids {
        if i in self._deleted {
            continue;
        }
        if (hit := self.__mem__.get(i)) is not None {
            out[i] = hit;
        } else {
            missing.append(i);
        }
    }
    if missing and self.store is not None {
        for attempt in range(2) {
            try {
                self.read_barrier();
                loaded = self.store.load_full(missing);
                for (rid, row) in loaded.items() {
                    anchor = self._materialize(row);
                    if anchor is not None {
                        self._fetch_count += 1;
                        out[rid] = anchor;
                    }
                }
                break;
            } except Exception as e {
                if attempt == 1 or not _is_serialization_conflict(e) {
                    raise;
                }
                self._recover_conflict();
            }
        }
    }
    return out;
}

impl Session.quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None {
    import from jaclang.runtime.osp_graph_sv { sv_forget_by_id }
    sid = stub.ensure_id();
    sv_forget_by_id(sid, self);
    if self.store is not None {
        try {
            self.store.quarantine(
                sid, referrer.ensure_id() if referrer else None, type(stub).__name__
            );
        } except Exception as e {
            logger.debug(f"quarantine record failed: {e}");
        }
    }
}
