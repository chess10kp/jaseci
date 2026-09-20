impl Session.flush(full: bool = False) -> None {
    import threading;
    import from jaclang.data.serializer { Serializer }
    if self.store is None {
        return;
    }
    with self._lock {
        if self._flushing == threading.get_ident() {
            return;
        }
        self._flushing = threading.get_ident();
        try {
            self._flush_locked(full);
        } finally {
            self._flushing = None;
        }
    }
}

impl Session._flush_locked(full: bool) -> None {
    if self.store is not None {
        candidates: list[UUID];
        if full {
            candidates = list(self.__mem__.keys());
        } else {
            candidates = list(self._dirty.keys());
        }
        rows: list[AnchorRow] = [];
        pending: list[tuple[Anchor, int]] = [];
        for id in candidates {
            anchor = self.__mem__.get(id);
            if anchor is None or not anchor.persistent or not anchor.is_populated() {
                continue;
            }
            h = _persist_hash(anchor);
            if h != 0 and self._flushed_hash.get(id) == h and id not in self._dirty {
                continue;
            }

            import from jaclang { JacRuntimeInterface as JacRI }
            if not JacRI.check_write_access(anchor, op_hint="field_write") {
                continue;
            }
            rows.append(self._serialize(anchor));
            pending.append((anchor, h));
        }
        if rows or self._deleted {
            self.ensure_writable_txn();
        }
        if rows {
            self.store.upsert(rows);
            for (i, (anchor, h)) in enumerate(pending) {
                aid = anchor.ensure_id();
                self._flushed_hash[aid] = h;
                anchor.hash = h;
                self._version_seen[aid] = rows[i].version;
                self._txn_changed.add(aid);
            }
        }
        if self._deleted {
            self.store.delete(list(self._deleted));
            for id in self._deleted {
                self._flushed_hash.pop(id, None);
                self._txn_changed.add(id);
            }
            self._deleted.clear();
        }
        self._dirty.clear();
    }
}

impl Session._serialize(anchor: Anchor) -> AnchorRow {
    import from jaclang.data.serializer { Serializer }
    props = Serializer.serialize(anchor, include_type=True);
    if isinstance(props, dict) {
        props.pop('edges', None);
    }
    arch = anchor.archetype;
    arch_type = '';
    arch_module = '';
    fingerprint = '';
    if anchor.is_populated() and arch is not None {
        arch_type = type(arch).__name__;
        arch_module = type(arch).__module__;
        fp = type(arch)?.__jac_fingerprint__;
        fingerprint = fp if isinstance(fp, str) else '';
    }
    src: (UUID | None) = None;
    dst: (UUID | None) = None;
    undirected = False;
    if isinstance(anchor, EdgeAnchor) {
        src = anchor.source.ensure_id() if anchor.source is not None else None;
        dst = anchor.target.ensure_id() if anchor.target is not None else None;
        undirected = anchor.is_undirected;
    }
    row_id = anchor.ensure_id();
    return AnchorRow(
        id=row_id,
        kind=type(anchor).__name__,
        arch_type=arch_type,
        arch_module=arch_module,
        fingerprint=fingerprint,
        root_id=anchor.root,
        version=self._version_seen.get(row_id, 0),
        props=props if isinstance(props, dict) else {},
        src=src,
        dst=dst,
        undirected=undirected,
        ancestry=_ancestry_of(arch)
    );
}

impl Session._materialize(row: AnchorRow) -> (Anchor | None) {
    import from functools { partial }
    import from jaclang.data.serializer { Serializer }
    existing = self.__mem__.get(row.id);
    if existing is not None and existing.is_populated() {
        return existing;
    }
    got = Serializer.deserialize(row.props);
    if not isinstance(got, Anchor) {
        logger.warning(
            f"could not materialize anchor {row.id} ({row.arch_type}); skipping"
        );
        if self.store is not None {
            try {
                self.store.quarantine(row.id, None, row.kind);
            } except Exception as e {
                logger.debug(f"quarantine record failed: {e}");
            }
        }
        return None;
    }
    anchor: Anchor = got;
    if isinstance(anchor, NodeAnchor) {
        if self.store is not None {
            anchor.__dict__.pop('edges', None);
            anchor.__dict__['_edge_loader'] = partial(self._load_edges, anchor);
        }
        anchor.version = row.version;
    }
    self._version_seen[row.id] = row.version;
    self.__mem__[row.id] = anchor;
    self._flushed_hash[row.id] = _persist_hash(anchor);
    anchor.hash = self._flushed_hash[row.id];
    if self.store is not None
        and self.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY {
        self._snapshot_reads.add(row.id);
    }
    return anchor;
}

impl Session._load_edges(nd: NodeAnchor) -> list[EdgeAnchor] {
    import from jaclang.data.serializer { Serializer }
    loaded = nd.__dict__.get('edges');
    if loaded is not None {
        return loaded;
    }
    ids: list[UUID] = [];
    if self.store is not None and nd.id is not None {
        self.read_barrier();
        after: (tuple[int, UUID] | None) = None;
        while True {
            page = self.store.adjacency(nd.id, after, EDGE_PAGE);
            for (seq, eid) in page {
                if eid not in self._deleted {
                    ids.append(eid);
                }
            }
            if len(page) < EDGE_PAGE {
                break;
            }
            after = page[-1];
        }
    }
    edges: list[EdgeAnchor] = [];
    for eid in ids {
        stub = Serializer._id_to_stub(EdgeAnchor, str(eid));
        if isinstance(stub, EdgeAnchor) {
            edges.append(stub);
        }
    }
    nd.__dict__['edges'] = edges;
    nd.__dict__['_initial_edge_ids'] = frozenset(ids);
    nd.__dict__.pop('_edge_loader', None);
    return edges;
}
