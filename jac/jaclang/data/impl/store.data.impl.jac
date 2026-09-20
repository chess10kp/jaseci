impl PgStore.begin(isolation: TxnIsolation = TxnIsolation.SERIALIZABLE) -> None {
    with self._lock {
        if self._in_txn {
            return;
        }
        self._run(f"BEGIN {isolation.value}", {});
        self._in_txn = True;
        self._isolation = isolation;
        try {
            self._run("SET LOCAL lock_timeout = '10s'", {});
        } except Exception {}
    }
}

impl PgStore.commit -> None {
    with self._lock {
        if not self._in_txn {
            return;
        }
        try {
            self._run('COMMIT', {});
        } finally {
            self._in_txn = False;
            self._isolation = None;
        }
    }
}

impl PgStore.rollback -> None {
    with self._lock {
        if not self._in_txn {
            return;
        }
        try {
            self._run('ROLLBACK', {});
        } finally {
            self._in_txn = False;
            self._isolation = None;
        }
    }
}

impl PgStore.in_txn -> bool {
    return self._in_txn;
}

impl PgStore.txn_isolation -> (TxnIsolation | None) {
    return self._isolation if self._in_txn else None;
}

impl PgStore.load_full(ids: list[UUID]) -> dict[UUID, AnchorRow] {
    if not ids {
        return {};
    }
    out: dict[UUID, AnchorRow] = {};
    rows = self._run(
        """
        SELECT a.id, a.kind, a.arch_type, a.arch_module, a.fingerprint,
               a.root_id, a.src, a.dst, a.undirected, a.props, a.version
        FROM anchors a WHERE a.id = ANY(CAST(:ids AS uuid[]))
        """,
        {'ids': [str(i) for i in ids]}
    );
    for r in rows {
        raw_props = r[9];
        props: dict[str, any] = (
            raw_props if isinstance(raw_props, dict) else json.loads(str(raw_props))
        );
        row = AnchorRow(
            id=UUID(str(r[0])),
            kind=str(r[1]),
            arch_type=str(r[2]),
            arch_module=str(r[3]),
            fingerprint=str(r[4]),
            root_id=UUID(str(r[5])) if r[5] else None,
            props=props,
            src=UUID(str(r[6])) if r[6] else None,
            dst=UUID(str(r[7])) if r[7] else None,
            undirected=bool(r[8]),
            version=int(str(r[10]))
        );
        out[row.id] = row;
    }
    return out;
}

impl PgStore.adjacency(
    node_id: UUID, after: (tuple[int, UUID] | None), limit: int
) -> list[tuple[int, UUID]] {
    rows = self._run(
        """
        SELECT u.seq, u.id FROM (
            SELECT e.seq, e.id FROM anchors e
             WHERE e.kind = 'EdgeAnchor' AND e.src = CAST(:i AS uuid)
            UNION ALL
            SELECT e.seq, e.id FROM anchors e
             WHERE e.kind = 'EdgeAnchor' AND e.dst = CAST(:i AS uuid)
               AND e.src <> CAST(:i AS uuid)
        ) u
        WHERE (u.seq, u.id) > (CAST(:s AS bigint), CAST(:a AS uuid))
        ORDER BY u.seq, u.id LIMIT CAST(:n AS bigint)
        """,
        {
            'i': str(node_id),
            's': int(after[0]) if after is not None else -1,
            'a': str(after[1]) if after is not None else str(UUID(int=0)),
            'n': int(limit)
        }
    );
    return [(int(str(r[0])), UUID(str(r[1]))) for r in rows];
}

impl PgStore.upsert(rows_in: list[AnchorRow]) -> None {
    if not rows_in {
        return;
    }
    by_id: dict[UUID, AnchorRow] = {row.id: row for row in rows_in};
    rows = list(by_id.values());
    stale: list[AnchorRow] = [];
    chunk = 200;
    for start in range(0, len(rows), chunk) {
        batch = rows[start:start + chunk];
        values: list[str] = [];
        params: dict[str, any] = {};
        for (i, row) in enumerate(batch) {
            values.append(
                f"(CAST(:id{i} AS uuid), :kind{i}, :arch_type{i}, "
                f":arch_module{i}, :fp{i}, CAST(:root_id{i} AS uuid), "
                f"CAST(:src{i} AS uuid), CAST(:dst{i} AS uuid), "
                f":undirected{i}, CAST(:props{i} AS jsonb), :fv{i}, :ver{i}, now())"
            );
            params[f"id{i}"] = str(row.id);
            params[f"kind{i}"] = row.kind;
            params[f"arch_type{i}"] = row.arch_type;
            params[f"arch_module{i}"] = row.arch_module;
            params[f"fp{i}"] = row.fingerprint;
            params[f"root_id{i}"] = str(row.root_id) if row.root_id else None;
            params[f"src{i}"] = str(row.src) if row.src else None;
            params[f"dst{i}"] = str(row.dst) if row.dst else None;
            params[f"undirected{i}"] = row.undirected;
            params[f"props{i}"] = json.dumps(row.props, `default=_jsonable);
            params[f"fv{i}"] = SCHEMA_VERSION;
            params[f"ver{i}"] = int(row.version);
        }
        written = self._run(
            """
            INSERT INTO anchors
                (id, kind, arch_type, arch_module, fingerprint, root_id,
                 src, dst, undirected, props, format_version, version, updated_at)
            VALUES
            """
                + ',\n'.join(values)
                + """
            ON CONFLICT (id) DO UPDATE SET
                kind = EXCLUDED.kind,
                arch_type = EXCLUDED.arch_type,
                arch_module = EXCLUDED.arch_module,
                fingerprint = EXCLUDED.fingerprint,
                root_id = EXCLUDED.root_id,
                src = EXCLUDED.src,
                dst = EXCLUDED.dst,
                undirected = EXCLUDED.undirected,
                props = EXCLUDED.props,
                format_version = EXCLUDED.format_version,
                version = EXCLUDED.version + 1,
                updated_at = now()
            WHERE anchors.version = EXCLUDED.version
            RETURNING id, version
            """,
            params
        );
        landed: dict[str, int] = {str(r[0]): int(r[1]) for r in written};
        for row in batch {
            got = landed.get(str(row.id));
            if got is None {
                stale.append(row);
            } else {
                row.version = got;
            }
        }
    }
    if stale {
        first = stale[0];
        found = self._run(
            'SELECT version FROM anchors WHERE id = CAST(:i AS uuid)',
            {'i': str(first.id)}
        );
        raise WriteConflict(
            anchor_id=first.id,
            expected_version=int(first.version),
            actual_version=int(found[0][0]) if found else -1
        );
    }
    pairs: list[tuple[str, str]] = [];
    seen_pairs: set[tuple[str, str]] = set();
    for row in rows {
        if row.arch_type and row.arch_type not in self._known_types {
            for anc in (row.ancestry or [row.arch_type]) {
                if (row.arch_type, anc) not in seen_pairs {
                    seen_pairs.add((row.arch_type, anc));
                    pairs.append((row.arch_type, anc));
                }
            }
        }
    }
    if pairs {
        tvals: list[str] = [];
        tparams: dict[str, any] = {};
        for (i, pair) in enumerate(pairs) {
            tvals.append(f"(:t{i}, :a{i})");
            tparams[f"t{i}"] = pair[0];
            tparams[f"a{i}"] = pair[1];
        }
        self._run(
            'INSERT INTO graph_types (type_name, ancestor) VALUES '
                + ', '.join(tvals)
                + ' ON CONFLICT DO NOTHING',
            tparams
        );
        for pair in pairs {
            self._known_types.add(pair[0]);
        }
    }
}

impl PgStore.delete(ids: list[UUID]) -> None {
    if not ids {
        return;
    }
    self._run(
        'DELETE FROM anchors WHERE id = ANY(CAST(:ids AS uuid[]))',
        {'ids': [str(i) for i in ids]}
    );
}

impl PgStore.existing(ids: list[UUID]) -> set[UUID] {
    if not ids {
        return set();
    }
    rows = self._run(
        'SELECT id FROM anchors WHERE id = ANY(CAST(:ids AS uuid[]))',
        {'ids': [str(i) for i in ids]}
    );
    return {UUID(str(r[0])) for r in rows};
}

impl PgStore.root_ids -> list[UUID] {
    rows = self._run(
        """
        SELECT id FROM anchors
        WHERE kind = 'NodeAnchor' AND arch_type = 'Root' ORDER BY id
        """,
        {}
    );
    return [UUID(str(r[0])) for r in rows];
}

impl PgStore.subtype_names(type_name: str) -> list[str] {
    rows = self._run(
        'SELECT type_name FROM graph_types WHERE ancestor = :t', {'t': type_name}
    );
    names = [str(r[0]) for r in rows];
    if type_name not in names {
        names.append(type_name);
    }
    return names;
}

impl PgStore.rows(sql: str, params: dict[str, any]) -> list[tuple[any, ...]] {
    return [tuple(r) for r in self._run(sql, params)];
}

impl PgStore.kv_get(key: str) -> (str | None) {
    rows = self._run(
        """
        SELECT value FROM kv_state
        WHERE key = :k AND (expires_at IS NULL OR expires_at > now())
        """,
        {'k': key}
    );
    return str(rows[0][0]) if rows else None;
}

impl PgStore.kv_put(key: str, value: str) -> None {
    self._run(
        """
        INSERT INTO kv_state (key, value, updated_at) VALUES (:k, :v, now())
        ON CONFLICT (key) DO UPDATE SET value = :v, updated_at = now()
        """,
        {'k': key, 'v': value}
    );
}

impl PgStore.kv_put_ttl(key: str, value: str, ttl_seconds: int) -> None {
    with self._lock {
        conn: any = self._side();
        conn.run(
            """
            INSERT INTO kv_state (key, value, expires_at, updated_at)
            VALUES (
                :k, :v, now() + make_interval(secs => CAST(:ttl AS int)), now()
            )
            ON CONFLICT (key) DO UPDATE SET
                value = EXCLUDED.value,
                expires_at = EXCLUDED.expires_at,
                updated_at = now()
            """,
            k=key,
            v=value,
            ttl=ttl_seconds
        );
    }
}

impl PgStore.kv_delete(key: str) -> None {
    self._run('DELETE FROM kv_state WHERE key = :k', {'k': key});
}

impl PgStore.kv_acquire_lease(key: str, ttl_seconds: int, owner: str) -> bool {
    with self._lock {
        conn: any = self._side();
        rows = conn.run(
            """
            INSERT INTO kv_state (key, value, expires_at, updated_at)
            VALUES (
                :k, :o, now() + make_interval(secs => CAST(:ttl AS int)), now()
            )
            ON CONFLICT (key) DO UPDATE SET
                value = EXCLUDED.value,
                expires_at = EXCLUDED.expires_at,
                updated_at = now()
            WHERE kv_state.value = :o
                  OR kv_state.expires_at IS NULL
                  OR kv_state.expires_at <= now()
            RETURNING key
            """,
            k=f"lease:{key}",
            o=owner,
            ttl=ttl_seconds
        );
    }
    return bool(rows);
}

impl PgStore.kv_release_lease(key: str, owner: str) -> bool {
    with self._lock {
        conn: any = self._side();
        rows = conn.run(
            'DELETE FROM kv_state WHERE key = :k AND value = :o RETURNING key',
            k=f"lease:{key}",
            o=owner
        );
    }
    return bool(rows);
}

impl PgStore.quarantine(
    missing_id: UUID, referrer_id: (UUID | None), kind: str
) -> None {
    if self._isolation is TxnIsolation.SNAPSHOT_READ_ONLY {
        return;
    }
    self._run(
        """
        INSERT INTO quarantine (missing_id, referrer_id, kind)
        VALUES (CAST(:m AS uuid), CAST(:r AS uuid), :k)
        ON CONFLICT DO NOTHING
        """,
        {
            'm': str(missing_id),
            'r': str(referrer_id) if referrer_id else None,
            'k': kind
        }
    );
}
