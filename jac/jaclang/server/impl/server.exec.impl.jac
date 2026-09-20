import asyncio;
import inspect;
import os;
import from inspect { iscoroutine }
import from jaclang.data.serializer { Serializer }
import from jaclang.runtime.exceptions { ReadOnlyRetry, WriteConflict }
import from jaclang.runtime.constants { Constants as Con }


impl ExecutionManager.report_collector(
    call_state: CallState
) -> list[JsonValue] | Generator | AsyncGenerator {
    import from queue { Empty }
    final_reports: list[JsonValue] = [];
    while True {
        try {
            report_item = call_state.reports.get_nowait();
        } except Empty {
            return final_reports;
        }
        if report_item is call_state._sentinel {
            return final_reports;
        } elif isgenerator(report_item) or isinstance(report_item, AsyncGenerator) {
            return report_item;
        } else {
            final_reports.append(report_item);
        }
    }
}

async def _begin_request_context(user_root_id: str) -> tuple[(ExecutionContext, any)] {
    import from jaclang.runtime.osp_kernel_sv { isolate_request_walk_stack }
    parent = Jac.get_context();
    req_ctx = ExecutionContext(_parent=parent);
    await req_ctx.aset_user_root(user_root_id);
    token = Jac.push_request_context(req_ctx);

    isolate_request_walk_stack();
    return (req_ctx, token);
}

async def _abegin_user_request_context(
    user_manager: UserManager, username: str
) -> tuple[(ExecutionContext, any, str)] | dict[str, JsonValue] {
    import from jaclang.runtime.exceptions { MissingAnchorError }
    root_id = await user_manager.aget_root_id(username);
    if not root_id {
        import os;
        if username != Con.GUEST.value and os.environ.get('JAC_SV_SIBLING') {
            ensure_root = getattr(
                user_manager, 'ensure_user_root', user_manager.get_root_id
            );
            root_id = await asyncio.to_thread(ensure_root, username);
        }
        if not root_id {
            return {'error': 'User not found'};
        }
    }
    try {
        (ctx, token) = await _begin_request_context(root_id);
        return (ctx, token, root_id);
    } except MissingAnchorError {
        if username != Con.GUEST.value {
            raise RuntimeError(
                f"Root anchor {root_id} for user '{username}' does not "
                "exist in the anchor store. The data store was likely "
                "reset or migrated out from under the users db; restore "
                "it or re-register the user."
            );
        }
        import logging;
        logging.getLogger('jaclang.serve').warning(
            f"Guest root anchor {root_id} is missing from the anchor store; "
            "minting a fresh guest root."
        );
        healed_id = await asyncio.to_thread(user_manager.reset_root, username);
        if not healed_id {
            return {'error': 'User not found'};
        }
        (ctx, token) = await _begin_request_context(healed_id);
        return (ctx, token, healed_id);
    }
}

def _deserialize_wire_args(args: dict[(str, any)]) {
    for (k, v) in list(args.items()) {
        if isinstance(v, dict) and '__type__' in v {
            deserialized = Serializer.deserialize(v);
            if deserialized is not None {
                args[k] = deserialized;
            }
        } elif isinstance(v, list) {
            args[k] = [
                Serializer.deserialize(item)
                    if isinstance(item, dict) and '__type__' in item
                    else item for item in v
            ];
        }
    }
}

impl observe_read_tier_retry(metrics: any, unit_key: str) -> None {
    import logging;
    logging.getLogger("jaclang.serve").info(
        f"read tier: unit {unit_key or '<anonymous>'} wrote inside a read-only "
        "snapshot; re-running at SERIALIZABLE and recording it as a writer"
    );
    if metrics is not None {
        try {
            metrics.record_read_tier_retry(unit_key);
        } except Exception as e {
            logging.getLogger("jaclang.serve").debug(
                f"read tier retry metric not recorded: {type(e).__name__}: {e}"
            );
        }
    }
}


def _unit_key_for(target: any) -> (str | None) {
    mod = str(getattr(target, '__module__', '') or '');
    name = str(getattr(target, '__name__', '') or '');
    if not name {
        return None;
    }
    return f"{mod}.{name}";
}


def _occ_policy -> tuple[str, int, int] {
    mode = "retry";
    max_attempts = 5;
    backoff_ms = 0;
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        if cfg is not None {
            mode = str(cfg.serve.on_conflict).strip().lower();
            if mode not in ("retry", "fail") {
                mode = "retry";
            }
            max_attempts = cfg.serve.conflict_max_attempts;
            backoff_ms = cfg.serve.conflict_backoff_ms;
        }
    } except Exception {}
    return (mode, max_attempts, backoff_ms);
}

impl ExecutionManager._finalize_call_response(
    call_state: CallState, result: any
) -> dict[str, JsonValue] | Generator | AsyncGenerator {
    call_state.reports.put_nowait(call_state._sentinel);
    reports = await self.report_collector(call_state);
    await Jac.acommit();
    if isgenerator(result) or isinstance(result, AsyncGenerator) {
        return result;
    }
    if isgenerator(reports) or isinstance(reports, AsyncGenerator) {
        return reports;
    }

    envelope: dict[str, object] = {
        'result': Serializer.serialize(result, api_mode=True),
        'reports': Serializer.serialize(reports, api_mode=True)
    };
    ctx = Jac.get_context();
    if ctx.diagnostics {
        envelope['warnings'] = [d.to_dict() for d in ctx.diagnostics];
        ctx.diagnostics.clear();
    }
    return dict[(str, JsonValue)](envelope);
}

async def _run_function_with_occ(
    mgr: ExecutionManager,
    args: dict[(str, any)],
    username: str,
    run_attempt: Callable,
    deserialize_args: bool = True,
    unit_key: (str | None) = None
) -> dict[str, JsonValue] | Generator | AsyncGenerator {
    resolved = await _abegin_user_request_context(mgr.user_manager, username);
    if isinstance(resolved, dict) {
        return resolved;
    }
    (ctx, req_token, root_id) = resolved;
    ctx.mem.unit_enter(unit_key);
    settled = False;
    try {
        if deserialize_args {
            _deserialize_wire_args(args);
        }
        (occ_mode, occ_max, occ_backoff_ms) = _occ_policy();
        max_attempts = 1 if occ_mode == "fail" else max(1, occ_max);
        attempt = 0;
        ro_retries = 0;
        while attempt < max_attempts {
            attempt += 1;
            call_token = ctx.call_state.set(CallState());
            call_state = ctx.call_state.get();
            try {
                outcome = await run_attempt(call_state, ctx);
                ctx.mem.unit_exit();
                settled = True;
                return outcome;
            } except ReadOnlyRetry as rr {
                settled = False;
                if ctx.mem.unit_depth() == 0 {
                    ctx.mem.unit_enter(unit_key);
                }
                ctx.mem.abort();
                ctx.pending_effects.clear();
                ctx.read_versions.clear();
                ctx.diagnostics.clear();
                ro_retries += 1;
                observe_read_tier_retry(mgr.metrics, rr.unit_key or unit_key or "");
                if ro_retries <= 2 {
                    attempt -= 1;
                }
                await ctx.aset_user_root(root_id);
            } except WriteConflict as wc {
                settled = False;
                if ctx.mem.unit_depth() == 0 {
                    ctx.mem.unit_enter(unit_key);
                }
                ctx.mem.abort();
                ctx.pending_effects.clear();
                ctx.read_versions.clear();

                ctx.diagnostics.clear();
                if attempt >= max_attempts {
                    return {
                        'error': wc.message(),
                        'error_code': 'write_conflict',
                        'http_status': 409
                    };
                }
                if occ_backoff_ms > 0 {
                    await asyncio.sleep(occ_backoff_ms * attempt / 1000.0);
                }
                await ctx.aset_user_root(root_id);
            } except Exception as e {
                ctx.mem.abort();
                import logging;
                logging.getLogger('jaclang.serve').exception(
                    f"{unit_key or 'request'} raised {type(e).__name__}: {e}"
                );
                return {'error': str(e), 'error_code': 'execution_error'};
            } finally {
                ctx.call_state.reset(call_token);
            }
        }
        return {
            'error': 'write_conflict: retries exhausted',
            'error_code': 'write_conflict',
            'http_status': 409
        };
    } finally {
        try {
            if not settled {
                ctx.mem.unit_exit();
            }
        } except Exception as ue {
            import logging;
            logging.getLogger(__name__).warning(
                f"unit exit failed: {type(ue).__name__}: {ue}"
            );
        }
        Jac.reset_request_context(req_token);
    }
}

impl ExecutionManager.execute_function(
    func: Callable[(..., any)], args: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    import inspect;

    if inspect.iscoroutinefunction(func) {
        return await self.execute_function_async(func, args, username);
    }
    return await self.execute_function_sync(func, args, username);
}

impl ExecutionManager.execute_function_sync(
    func: Callable[(..., any)], args: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    async def run_attempt(
        call_state: CallState, _ctx: ExecutionContext
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator {
        result = await asyncio.to_thread(func, **args);

        if iscoroutine(result) {
            result = await result;
        }
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(
        self, args, username, run_attempt, unit_key=_unit_key_for(func)
    );
}

impl ExecutionManager.execute_function_async(
    func: Callable[(..., any)], args: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    async def run_attempt(
        call_state: CallState, _ctx: ExecutionContext
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator {
        result = await func(**args);
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(
        self, args, username, run_attempt, unit_key=_unit_key_for(func)
    );
}

impl ExecutionManager.spawn_walker(
    walker_cls: type[WalkerArchetype], fields: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    if walker_cls.__jac_async__ {
        return await self.spawn_walker_async(walker_cls, fields, username);
    }
    return await self.spawn_walker_sync(walker_cls, fields, username);
}

impl ExecutionManager.spawn_walker_sync(
    walker_cls: type[WalkerArchetype], fields: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    import from jaclang.runtime.constructs { NodeArchetype }
    target_node_id = fields.pop('_jac_spawn_node', None);
    _deserialize_wire_args(fields);

    async def run_attempt(
        call_state: CallState, ctx: ExecutionContext
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator {
        `walker = walker_cls(**fields);
        if target_node_id {
            target_node = await Jac.aget_object(target_node_id);
            if not isinstance(target_node, NodeArchetype) {
                return {'error': f"Invalid target node: {target_node_id}"};
            }
        } else {
            target_node = ctx.get_root();
        }
        result = await asyncio.to_thread(Jac.`spawn, `walker, target_node);

        if iscoroutine(result) {
            result = await result;
        }
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(
        self,
        fields,
        username,
        run_attempt,
        deserialize_args=False,
        unit_key=_unit_key_for(walker_cls)
    );
}

impl ExecutionManager.spawn_walker_async(
    walker_cls: type[WalkerArchetype], fields: dict[(str, any)], username: str
) -> dict[str, JsonValue] {
    import from jaclang.runtime.constructs { NodeArchetype }
    target_node_id = fields.pop('_jac_spawn_node', None);
    _deserialize_wire_args(fields);

    async def run_attempt(
        call_state: CallState, ctx: ExecutionContext
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator {
        `walker = walker_cls(**fields);
        if target_node_id {
            target_node = await Jac.aget_object(target_node_id);
            if not isinstance(target_node, NodeArchetype) {
                return {'error': f"Invalid target node: {target_node_id}"};
            }
        } else {
            target_node = ctx.get_root();
        }
        spawn_result = Jac.`spawn(`walker, target_node);
        if iscoroutine(spawn_result) {
            result = await spawn_result;
        } else {
            result = spawn_result;
        }
        return await self._finalize_call_response(call_state, result);
    }
    return await _run_function_with_occ(
        self,
        fields,
        username,
        run_attempt,
        deserialize_args=False,
        unit_key=_unit_key_for(walker_cls)
    );
}
