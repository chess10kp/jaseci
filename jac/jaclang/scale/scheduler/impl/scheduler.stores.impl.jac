impl PgJobStore.insert(job: dict[str, any]) -> str {
    d = dict(job);
    job_id = str(d['job_id']);
    self.store.rows(
        'INSERT INTO jac_docs (collection, id, doc) '
        'VALUES (:c, :i, CAST(:d AS jsonb)) '
        'ON CONFLICT (collection, id) DO UPDATE SET doc = EXCLUDED.doc',
        {'c': self._collection, 'i': job_id, 'd': json.dumps(d, `default=str)}
    );
    return job_id;
}

impl PgJobStore.find_active(
    limit: int | None = None,
    offset: int = 0,
    trigger: str | None = None,
    created_by: str | None = None
) -> tuple[list[dict[str, any]], int] {
    conds: list[str] = ["collection = :c", "doc->>'status' = 'active'"];
    params: dict[str, any] = {'c': self._collection};
    if trigger {
        conds.append("doc->>'trigger' = :t");
        params['t'] = trigger;
    }
    if created_by {
        conds.append("doc->>'created_by' = :u");
        params['u'] = created_by;
    }
    where = ' AND '.join(conds);
    total = int(
        self.store.rows(f"SELECT count(*) FROM jac_docs WHERE {where}", params)[0][0]
    );
    page_sql = f"SELECT doc FROM jac_docs WHERE {where} ORDER BY id";
    if limit is not None {
        page_sql += " LIMIT :lim";
        params['lim'] = int(limit);
    }
    if offset > 0 {
        page_sql += " OFFSET :off";
        params['off'] = int(offset);
    }
    rows = self.store.rows(page_sql, params);
    return ([_doc_row(r[0]) for r in rows], total);
}

impl PgJobStore.find_active_one(job_id: str) -> dict[str, any] | None {
    rows = self.store.rows(
        "SELECT doc FROM jac_docs WHERE collection = :c AND id = :i "
        "AND doc->>'status' = 'active'",
        {'c': self._collection, 'i': job_id}
    );
    return _doc_row(rows[0][0]) if rows else None;
}

impl PgJobStore.update(
    job_id: str, updates: dict[str, any], where: dict[str, any] | None = None
) -> bool {
    params: dict[str, any] = {
        'c': self._collection,
        'i': job_id,
        'u': json.dumps(dict(updates), `default=str)
    };
    cond = _where_sql(where, params);
    rows = self.store.rows(
        f"UPDATE jac_docs SET doc = doc || CAST(:u AS jsonb) "
        f"WHERE collection = :c AND id = :i{cond} RETURNING id",
        params
    );
    return len(rows) > 0;
}

impl PgJobStore.delete(job_id: str, where: dict[str, any] | None = None) -> bool {
    params: dict[str, any] = {'c': self._collection, 'i': job_id};
    cond = _where_sql(where, params);
    rows = self.store.rows(
        f"DELETE FROM jac_docs WHERE collection = :c AND id = :i{cond} RETURNING id",
        params
    );
    return len(rows) > 0;
}

impl PgJobStore.record_run(job_id: str, status: str, error: str | None = None) -> None {
    updates = {
        'last_run_at': _utc_now_iso(),
        'last_status': status,
        'last_error': error
    };
    self.store.rows(
        "UPDATE jac_docs SET doc = doc || CAST(:u AS jsonb) || jsonb_build_object("
        "'run_count', COALESCE((doc->>'run_count')::bigint, 0) + 1) "
        "WHERE collection = :c AND id = :i",
        {'c': self._collection, 'i': job_id, 'u': json.dumps(updates, `default=str)}
    );
}

impl MemoryJobStore.postinit -> None {
    self._jobs = {};
}

impl MemoryJobStore.insert(job: dict[str, any]) -> str {
    job_id = str(job['job_id']);
    self._jobs[job_id] = dict(job);
    return job_id;
}

impl MemoryJobStore.find_active(
    limit: int | None = None,
    offset: int = 0,
    trigger: str | None = None,
    created_by: str | None = None
) -> tuple[list[dict[str, any]], int] {
    matches: list[dict[str, any]] = [];
    for j in self._jobs.values() {
        if j.get('status') != 'active' {
            continue;
        }
        if trigger is not None and j.get('trigger') != trigger {
            continue;
        }
        if created_by is not None and j.get('created_by') != created_by {
            continue;
        }
        matches.append(j);
    }
    total = len(matches);
    end = (offset + limit) if limit is not None else total;
    return (matches[offset:end], total);
}

impl MemoryJobStore.find_active_one(job_id: str) -> dict[str, any] | None {
    job = self._jobs.get(job_id);
    if job and job.get('status') == 'active' {
        return job;
    }
    return None;
}

impl MemoryJobStore.update(
    job_id: str, updates: dict[str, any], where: dict[str, any] | None = None
) -> bool {
    job = self._jobs.get(job_id);
    if job is None {
        return False;
    }
    if where {
        for (k, v) in where.items() {
            if job.get(k) != v {
                return False;
            }
        }
    }
    job.update(updates);
    return True;
}

impl MemoryJobStore.delete(job_id: str, where: dict[str, any] | None = None) -> bool {
    job = self._jobs.get(job_id);
    if job is None {
        return False;
    }
    if where {
        for (k, v) in where.items() {
            if job.get(k) != v {
                return False;
            }
        }
    }
    del self._jobs[job_id];
    return True;
}

impl MemoryJobStore.record_run(
    job_id: str, status: str, error: str | None = None
) -> None {
    job = self._jobs.get(job_id);
    if job is None {
        return;
    }
    job['last_run_at'] = _utc_now_iso();
    job['last_status'] = status;
    job['last_error'] = error;
    job['run_count'] = int(job.get('run_count', 0)) + 1;
}
