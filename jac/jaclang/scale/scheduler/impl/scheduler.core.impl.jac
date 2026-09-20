impl JacScaleScheduler.postinit -> None {
    logging.getLogger('apscheduler').setLevel(logging.ERROR);
    self._user_exists_cache = {};
}

impl JacScaleScheduler._user_is_live(user_id: str) -> bool {
    import time;
    now = time.time();
    expires_at = self._user_exists_cache.get(user_id, 0.0);
    if expires_at > now {
        return True;
    }
    if self._server is None {
        return False;
    }
    if self._server.user_manager.user_exists(user_id) {
        self._user_exists_cache[user_id] = now + self._user_exists_ttl;
        return True;
    }

    self._user_exists_cache.pop(user_id, None);
    return False;
}

impl JacScaleScheduler._require_store -> JobStore {
    if self._store is None {
        raise RuntimeError(
            "JacScaleScheduler not initialized — call setup() before using the store"
        );
    }
    return self._store;
}

impl JacScaleScheduler.instance -> JacScaleScheduler {
    if _jaclang_scale_scheduler is not None {
        return _jaclang_scale_scheduler;
    }
    _jaclang_scale_scheduler = JacScaleScheduler();
    return _jaclang_scale_scheduler;
}

impl JacScaleScheduler.setup(system_user_id: str, server: any | None = None) -> None {
    self._system_user_id = system_user_id;
    self._server = server;

    def _dynamic_handler(task: any) {
        self._execute_task(task.name, self._system_user_id, task.is_walker);
    }
    Scheduler.instance().dynamic_handler = _dynamic_handler;

    scheduler_cfg = get_scale_config().get_scheduler_config();
    collection = scheduler_cfg.get('collection', 'scheduled_jobs');
    store: any = None;
    try {
        store = open_docs_store();
    } except Exception as e {
        logger.warning(f"scheduler job store unavailable: {e}");
    }
    if store is not None {
        self._store = PgJobStore(store=store, _collection=collection);
        logger.debug("database configured - jobs will be persisted");
    } else {
        logger.warning(
            "No reachable database: dynamic jobs run IN MEMORY only. "
            "POST /jobs will accept jobs that vanish on restart and never "
            "fire on other pods. Fix [scale.database] url / JAC_DB_URL for "
            "durable scheduling."
        );
        self._store = MemoryJobStore();
    }
    self._user_exists_ttl = float(scheduler_cfg.get('user_exists_ttl', 30.0));

    if HAS_APSCHEDULER {
        pool_size = int(scheduler_cfg.get('thread_pool_size', 10));
        misfire = int(scheduler_cfg.get('misfire_grace_time', 60));
        executors = {'default': ThreadPoolExecutor(pool_size)};
        job_defaults = {
            'coalesce': False,
            'max_instances': 1,
            'misfire_grace_time': misfire
        };

        self._apscheduler = BackgroundScheduler(
            executors=executors,
            job_defaults=job_defaults,
            timezone=datetime.timezone.utc
        );
        logger.debug(
            f"APScheduler initialized (pool_size={pool_size}, misfire_grace={misfire}s, tz=UTC)"
        );
    } else {
        self._apscheduler = None;
        logger.info(
            "APScheduler not installed — dynamic scheduling disabled. "
            "Enable the 'scheduler' capability and run 'jac install'."
        );
    }
}

impl JacScaleScheduler.start -> None {
    if self._apscheduler is not None {
        try {
            self._apscheduler.start();
            logger.info("APScheduler started (timezone=UTC)");
        } except Exception as e {
            logger.error(f"Failed to start APScheduler: {e}");
        }
    }
    self._start_jobs_listener();
}

impl JacScaleScheduler.stop(drain: bool = False) -> None {
    if self._apscheduler is not None and self._apscheduler.running {
        try {
            self._apscheduler.shutdown(`wait=drain);
            logger.info(f"Scheduler stopped (drain={drain})");
        } except Exception as e {
            logger.debug(f"Error stopping APScheduler: {e}");
        }
    }
    try {
        Scheduler.instance().stop();
    } except Exception as e {
        logger.debug(f"Error stopping base Scheduler: {e}");
    }
}

impl JacScaleScheduler.register_dynamic_tasks_from_db -> None {
    if self._apscheduler is None {
        return;
    }
    (jobs, _total) = self._require_store().find_active();
    restored = 0;
    orphaned = 0;
    failed = 0;
    for job_data in jobs {
        job_id = str(job_data.get('job_id', str(uuid4())));
        name = job_data.get('name', '');
        user_id = job_data.get('created_by', self._system_user_id);
        is_walker = job_data.get('is_walker', True);
        if not name {
            continue;
        }
        if user_id != self._system_user_id and not self._user_is_live(user_id) {
            try {
                self._require_store().update(
                    job_id,
                    {'status': 'orphaned', 'orphaned_at': _utc_now_iso()},
                    where={'status': 'active'}
                );
            } except Exception as e {
                logger.debug(f"Could not mark job {job_id} orphaned: {e}");
            }
            logger.warning(
                f"Skipping restore of '{name}' (id={job_id}): creator '{user_id}' no longer exists"
            );
            orphaned += 1;
            continue;
        }
        try {
            spec = TriggerSpec.from_dict(job_data);
            self._schedule_apscheduler_job(
                job_id=job_id,
                name=name,
                spec=spec,
                user_id=user_id,
                is_walker=is_walker
            );
            logger.debug(f"Restored dynamic job: {name} (id={job_id})");
            restored += 1;
        } except Exception as e {
            logger.error(f"Failed to restore job '{name}': {e}");
            failed += 1;
        }
    }
    if restored or failed or orphaned {
        logger.info(
            f"Dynamic job restoration complete: {restored} restored, "
            f"{orphaned} orphaned, {failed} failed"
        );
    } else {
        logger.info("No persisted dynamic jobs to restore");
    }
}

impl JacScaleScheduler.create_job(
    name: str, spec: TriggerSpec, created_by: str
) -> dict[str, any] {
    if self._apscheduler is None {
        raise RuntimeError(
            "APScheduler is not available — enable the 'scheduler' capability and run 'jac install'."
        );
    }

    job_id = str(uuid4());
    now_str = _utc_now_iso();

    introspector = self._server.introspector if self._server else None;
    is_walker = name in (introspector._walkers or {}) if introspector else False;

    job_data: dict[str, any] = {
        'job_id': job_id,
        'name': name,
        'created_by': created_by,
        'is_walker': is_walker,
        'created_at': now_str,
        'status': 'active'
    };
    job_data.update(spec.to_dict());

    store = self._require_store();
    persisted_id = store.insert(job_data);
    job_data['job_id'] = persisted_id;

    try {
        self._schedule_apscheduler_job(
            job_id=persisted_id,
            name=name,
            spec=spec,
            user_id=created_by,
            is_walker=is_walker
        );
    } except Exception {
        try {
            store.delete(persisted_id);
        } except Exception as rollback_err {
            logger.error(
                f"Failed to roll back zombie job record {persisted_id} after "
                f"schedule failure: {type(rollback_err).__name__}: {rollback_err}"
            );
        }
        raise;
    }

    self._notify_jobs_changed(persisted_id);
    logger.debug(f"Created dynamic job: {name} (id={persisted_id})");
    return job_data;
}

impl JacScaleScheduler.list_jobs(
    limit: int | None = None,
    offset: int = 0,
    trigger: str | None = None,
    created_by: str | None = None
) -> tuple[list[dict[str, any]], int] {
    return self._require_store().find_active(
        limit=limit, offset=offset, trigger=trigger, created_by=created_by
    );
}

impl JacScaleScheduler.get_job(job_id: str) -> (dict[str, any] | None) {
    return self._require_store().find_active_one(job_id);
}

impl JacScaleScheduler.update_job(
    job_id: str, spec: TriggerSpec, acting_as: str | None = None
) -> (dict[str, any] | None) {
    existing = self.get_job(job_id);
    if existing is None {
        return None;
    }

    name = existing.get('name', '');
    user_id = existing.get('created_by', self._system_user_id);
    is_walker = existing.get('is_walker', True);
    updates: dict[str, any] = {'updated_at': _utc_now_iso()};
    updates.update(spec.to_dict());

    where = {'created_by': acting_as} if acting_as is not None else None;

    if not self._require_store().update(job_id, updates, where=where) {
        return None;
    }
    if self._apscheduler is not None {
        self._schedule_apscheduler_job(
            job_id=job_id, name=name, spec=spec, user_id=user_id, is_walker=is_walker
        );
    }
    self._notify_jobs_changed(job_id);

    updated = dict(existing);
    updated.update(updates);
    logger.debug(f"Updated dynamic job: {name} (id={job_id})");
    return updated;
}

impl JacScaleScheduler.delete_job(job_id: str, acting_as: str | None = None) -> bool {
    where = {'created_by': acting_as} if acting_as is not None else None;

    result = self._require_store().delete(job_id, where=where);
    if result and self._apscheduler is not None {
        try {
            self._apscheduler.remove_job(job_id);
        } except Exception as e {
            logger.warning(
                f"DB row for job {job_id} deleted but APScheduler.remove_job failed: {e}. "
                f"Job may keep firing until restart."
            );
        }
        logger.debug(f"Deleted dynamic job id={job_id}");
    }
    if result {
        self._notify_jobs_changed(job_id);
    }
    return result;
}

impl JacScaleScheduler._execute_task(
    name: str, user_id: str, is_walker: bool, job_id: str | None = None
) -> None {
    import asyncio;
    label = 'walker' if is_walker else 'function';
    try {
        if self._server is None {
            logger.error(f"Cannot execute {label} '{name}': server reference not set");
            self._mark_failed(job_id, 'server reference not set');
            return;
        }
        introspector = self._server.introspector;
        registry: dict[str, any] = (
            introspector._walkers if is_walker else introspector._functions
        )
            or {};
        target = registry.get(name);
        if target is None {
            logger.warning(
                f"Scheduled {label} '{name}' is no longer registered in the server"
            );
            self._mark_failed(job_id, 'target not registered');
            return;
        }

        async def _run {
            import from jaclang.scale.memory.context { JScaleExecutionContext }
            import from jaclang { JacRuntime as Jac }

            ctx = JScaleExecutionContext();
            ctx_token = Jac.push_request_context(ctx);
            try {
                if is_walker {
                    result = await self._server.execution_manager.spawn_walker(
                        target, {}, user_id
                    );
                } else {
                    result = await self._server.execution_manager.execute_function(
                        target, {}, user_id
                    );
                }
                if isinstance(result, dict) and 'error' in result {
                    err = str(result.get('error'));
                    logger.error(f"Scheduled {label} '{name}' error: {err}");
                    self._mark_failed(job_id, err);
                } elif job_id {
                    self._record_run(job_id, 'succeeded');
                }
            } finally {
                try {
                    ctx.mem.close();
                } except Exception as ce {
                    logger.warning(f"Scheduled job context close failed: {ce}");
                } finally {
                    Jac.reset_request_context(ctx_token);
                }
            }
        }

        asyncio.run(_run());
    } except Exception as e {
        logger.error(f"Error executing {label} '{name}': {e}");
        self._mark_failed(job_id, str(e));
    }
}

impl JacScaleScheduler._record_run(
    job_id: str, status: str, error: str | None = None
) -> None {
    try {
        self._require_store().record_run(job_id, status, error);
    } except Exception as e {
        logger.warning(f"Could not record run for job {job_id}: {e}");
    }
}

impl JacScaleScheduler._mark_failed(job_id: str | None, reason: str) -> None {
    if job_id {
        self._record_run(job_id, 'failed', reason);
    }
}

impl JacScaleScheduler._acquire_fire_lease(job_id: str, spec: TriggerSpec) -> bool {
    store = self._store;
    if not isinstance(store, PgJobStore) {
        return True;
    }
    import from jaclang.scale.state.pg_state_backend { PgStateBackend }
    try {
        return PgStateBackend(store=store.store).acquire_lock(
            f"sched:{job_id}", _fire_lease_ttl(spec)
        );
    } except Exception as e {
        logger.warning(f"fire-lease check failed for job {job_id}: {e}; firing anyway");
        return True;
    }
}

impl JacScaleScheduler._notify_jobs_changed(job_id: str) -> None {
    store = self._store;
    if not isinstance(store, PgJobStore) {
        return;
    }
    try {
        store.store.notify(JOBS_CHANGED_CHANNEL, job_id);
    } except Exception as e {
        logger.warning(
            f"jobs-changed notify failed for {job_id}: {e}; other pods "
            "reconcile this job on their next restart"
        );
    }
}

impl JacScaleScheduler._start_jobs_listener -> None {
    store = self._store;
    if not isinstance(store, PgJobStore) or self._apscheduler is None {
        return;
    }
    def _cb(payload: str) {
        self._on_jobs_changed(payload);
    }
    try {
        store.store.listen(JOBS_CHANGED_CHANNEL, _cb);
        logger.debug("jobs-changed listener registered");
    } except Exception as e {
        logger.warning(f"could not register jobs-changed listener: {e}");
    }
}

impl JacScaleScheduler._on_jobs_changed(payload: str) -> None {
    job_id = str(payload or '').strip();
    if not job_id or self._apscheduler is None or self._store is None {
        return;
    }
    try {
        job = self._store.find_active_one(job_id);
    } except Exception as e {
        logger.warning(f"jobs-changed reconcile failed for {job_id}: {e}");
        return;
    }
    if job is None {
        try {
            self._apscheduler.remove_job(job_id);
            logger.debug(f"jobs-changed: removed local schedule for {job_id}");
        } except Exception {}
        return;
    }
    try {
        self._schedule_apscheduler_job(
            job_id=job_id,
            name=str(job.get('name', '')),
            spec=TriggerSpec.from_dict(job),
            user_id=str(job.get('created_by', self._system_user_id)),
            is_walker=bool(job.get('is_walker', True))
        );
        logger.debug(f"jobs-changed: reconciled local schedule for {job_id}");
    } except Exception as e {
        logger.warning(f"jobs-changed re-schedule failed for {job_id}: {e}");
    }
}

impl JacScaleScheduler._schedule_apscheduler_job(
    job_id: str, name: str, spec: TriggerSpec, user_id: str, is_walker: bool = True
) -> None {
    if self._apscheduler is None {
        raise RuntimeError("APScheduler is not initialized");
    }

    def job_func {
        if not self._acquire_fire_lease(job_id, spec) {
            logger.debug(f"job {job_id} already fired on another pod; skipping");
            return;
        }
        if user_id != self._system_user_id and self._server is not None {
            if not self._user_is_live(user_id) {
                logger.warning(
                    f"Job '{name}' (id={job_id}) creator '{user_id}' no longer exists — marking orphaned"
                );

                self._require_store().update(
                    job_id,
                    {'status': 'orphaned', 'orphaned_at': _utc_now_iso()},
                    where={'status': 'active'}
                );
                try {
                    self._apscheduler.remove_job(job_id);
                } except Exception as e {
                    logger.debug(
                        f"Could not remove orphaned APScheduler job {job_id}: {e}"
                    );
                }
                return;
            }
        }
        self._execute_task(name, user_id, is_walker, job_id=job_id);
    }

    self._apscheduler.add_job(
        job_func,
        spec.trigger,
        id=job_id,
        replace_existing=True,
        **spec.apscheduler_kwargs()
    );
}
