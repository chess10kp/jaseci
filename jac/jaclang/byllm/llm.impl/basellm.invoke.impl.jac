impl BaseLLM.ainvoke(mt_run: MTRuntime) -> any {
    import asyncio;
    logging_stream = mt_run.stream and mt_run.call_params.get("logging", False);
    no_tools = len(mt_run.tools) == 0;
    if not mt_run.stream and no_tools and not logging_stream {
        return await self._ainvoke_typed_retry(mt_run);
    }
    if mt_run.stream and no_tools and not logging_stream {
        return self.adispatch_streaming(mt_run);
    }
    return await asyncio.to_thread(self.invoke, mt_run);
}

impl BaseLLM.__call__(**kwargs: object) -> BaseLLM {
    self.call_params = kwargs;
    return self;
}

impl BaseLLM.invoke(mt_run: MTRuntime) -> any {
    handler = mt_run.call_params.get("stream_handler");
    if mt_run.stream and handler is not None and callable(handler) {
        return self._invoke_with_handler(mt_run, cast(Callable, handler));
    }

    if mt_run.stream and mt_run.call_params.get("logging", False) {
        return self._invoke_streaming(mt_run);
    }

    if mt_run.stream and len(mt_run.tools) == 0 {
        return self.dispatch_streaming(mt_run);
    }

    if mt_run.stream {
        return self._invoke_react_loop_streaming(mt_run);
    }
    return self._invoke_typed_retry(mt_run);
}

impl BaseLLM._invoke_react_loop_streaming(
    mt_run: MTRuntime
) -> Generator[object, None, None] {
    import types as _types_mod;
    try {
        result = self._invoke_react_loop(mt_run);
        if isinstance(result, _types_mod.GeneratorType) {
            yield from result;
        } elif result is not None {
            yield result;
        }
    } finally {
        mt_run.write_back_conversation();
    }
}

impl BaseLLM._invoke_with_handler(mt_run: MTRuntime, on_event: Callable) -> object {
    if len(mt_run.tools) == 0
        and mt_run.resp_type is not None
        and mt_run.resp_type is not str {
        accumulated = "";
        _seen_resets = mt_run._stream_reset_count;
        try {
            for token in self.dispatch_streaming(mt_run) {
                if mt_run._stream_reset_count != _seen_resets {
                    _seen_resets = mt_run._stream_reset_count;
                    accumulated = "";
                    try {
                        on_event(
                            StreamEvent(
                                event_type="stream_reset", data={"scope": "answer"}
                            )
                        );
                    } except Exception as e {
                        logger.debug(f"stream_handler raised: {e}");
                    }
                }
                if token {
                    accumulated += token;
                    try {
                        on_event(
                            StreamEvent(event_type="chunk", data={"content": token})
                        );
                    } except Exception as e {
                        logger.debug(f"stream_handler raised: {e}");
                    }
                }
            }
        } finally {
            mt_run.write_back_conversation();
        }

        if mt_run._usage_history {
            try {
                on_event(
                    StreamEvent(
                        event_type="llm_timing",
                        data={"duration_ms": 0.0, "iteration": 0}
                    )
                );
            } except Exception as e {
                logger.debug(f"stream_handler raised: {e}");
            }
        }
        return mt_run.parse_response(accumulated);
    }

    parts: list[str] = [];
    for ev in self._invoke_streaming(mt_run) {
        try {
            on_event(ev);
        } except Exception as e {
            logger.debug(f"stream_handler raised: {e}");
        }
        if ev.event_type == "stream_reset" {
            parts = [];
        } elif ev.event_type == "chunk" {
            parts.append(str(ev.data.get("content", "")));
        }
    }
    if mt_run._has_final_output
        and mt_run.resp_type is not None
        and mt_run.resp_type is not str {
        return mt_run._final_output;
    }
    return "".join(parts);
}

impl BaseLLM._invoke_react_loop(mt_run: MTRuntime) -> object {
    max_iters = (
        mt_run.call_params.get("max_react_iterations")
        or self.call_params.get("max_react_iterations")
        or _call_params_config.get("max_react_iterations")
        or 0
    );
    on_iteration = (
        mt_run.call_params.get("on_iteration") or self.call_params.get("on_iteration")
    );
    _cp = self._resolve_compaction_params(mt_run);
    iter_count = 0;
    last_tool = "";
    last_result = "";
    total_tokens = 0;
    just_compacted = False;
    while True {
        iter_count += 1;
        if on_iteration and iter_count > 1 {
            ctx = IterationContext(
                iteration=iter_count,
                messages=mt_run.messages,
                last_tool=last_tool,
                last_result=last_result,
                total_tokens=total_tokens,
                total_cost=_usage_history_total_cost(mt_run)
            );
            action = on_iteration(ctx);
            if action == IterationAction.ABORT {
                return last_result;
            }
            if action == IterationAction.ABORT_WITH_SUMMARY {
                if mt_run.stream {
                    return self._stream_final_answer(mt_run);
                }
                return self._force_final_answer(mt_run);
            }
        }
        if int(max_iters) > 0 and iter_count > int(max_iters) {
            if mt_run.stream {
                return self._stream_final_answer(mt_run);
            }
            return self._force_final_answer(mt_run);
        }
        try {
            resp = self.dispatch_no_streaming(mt_run);
        } except litellm.exceptions.ContextWindowExceededError {
            resp = self._emergency_compact_retry(mt_run, just_compacted, _cp);
            just_compacted = True;
        } except OutputConversionError {
            recovery_resp = self._attempt_recovery(mt_run);
            if recovery_resp is None {
                raise;
            }
            if recovery_resp.tool_calls {
                for tool_call in recovery_resp.tool_calls {
                    if tool_call.is_finish_call() {
                        mt_run.add_message(tool_call());
                        return tool_call.get_output();
                    }
                }
            }
            return recovery_resp.output;
        }
        usage: dict[str, any] = resp.usage or {};
        total_tokens += int(
            usage.get("total_tokens", 0)
                if isinstance(usage, dict)
                else getattr(usage, "total_tokens", 0)
        );

        just_compacted = self._maybe_compact(mt_run, usage, just_compacted, _cp);
        if resp.tool_calls {
            non_finish_calls: list[ToolCall] = [];
            finish_tc: (ToolCall | None) = None;
            for tc in resp.tool_calls {
                if tc.is_finish_call() {
                    finish_tc = tc;
                    break;
                }
                non_finish_calls.append(tc);
            }

            if non_finish_calls {
                batches = (
                    [non_finish_calls]
                        if _should_parallelize(mt_run)
                        else [[tc] for tc in non_finish_calls]
                );
                for batch in batches {
                    raw_results: list[tuple[ToolCall, Message, float]] = list(
                        dispatch_batch(batch)
                    );
                    ordered: dict[int, tuple[ToolCall, Message, float]] = {};
                    for r in raw_results {
                        idx = _index_by_identity(batch, r[0]);
                        ordered[idx] = r;
                    }
                    for i in range(len(batch)) {
                        (btc, result_msg, _ms) = ordered[i];
                        last_tool = btc.tool.get_name();
                        last_result = str(result_msg.content)[:500];
                        mt_run.add_message(result_msg);
                    }
                }
            }

            if finish_tc {
                try {
                    finish_msg = finish_tc();
                    final_output = finish_tc.get_output();
                } except FinishToolError as e {
                    mt_run.add_message(
                        _error_tool_call(finish_tc.call_id, "finish_tool", str(e))()
                    );
                    continue;
                }
                mt_run.add_message(finish_msg);
                if mt_run.stream {
                    return self._stream_final_answer(mt_run);
                }
                return final_output;
            }
        } else {
            recovery_resp = self._attempt_recovery(mt_run);
            if recovery_resp is None {
                break;
            }
            if recovery_resp.tool_calls {
                for tool_call in recovery_resp.tool_calls {
                    if tool_call.is_finish_call() {
                        mt_run.add_message(tool_call());
                        return tool_call.get_output();
                    }
                }
            }
            return recovery_resp.output;
        }
    }
    return resp.output;
}

impl BaseLLM._invoke_streaming(
    mt_run: MTRuntime
) -> Generator[StreamEvent, None, None] {
    if len(mt_run.tools) == 0 {
        _seen_resets = mt_run._stream_reset_count;
        for token in self.dispatch_streaming(mt_run) {
            if mt_run._stream_reset_count != _seen_resets {
                _seen_resets = mt_run._stream_reset_count;
                yield StreamEvent(event_type="stream_reset", data={"scope": "answer"});
            }
            if token {
                yield StreamEvent(event_type="chunk", data={"content": token});
            }
        }
    } else {
        max_iters = (
            mt_run.call_params.get("max_react_iterations")
            or self.call_params.get("max_react_iterations")
            or _call_params_config.get("max_react_iterations")
            or 0
        );
        on_iteration = (
            mt_run.call_params.get("on_iteration")
            or self.call_params.get("on_iteration")
        );
        _cp = self._resolve_compaction_params(mt_run);
        iter_count = 0;
        last_tool = "";
        last_result = "";
        total_tokens = 0;
        just_compacted = False;
        while True {
            iter_count += 1;
            _usage_base = len(mt_run._usage_history);

            if on_iteration and iter_count > 1 {
                ctx = IterationContext(
                    iteration=iter_count,
                    messages=mt_run.messages,
                    last_tool=last_tool,
                    last_result=last_result,
                    total_tokens=total_tokens,
                    total_cost=_usage_history_total_cost(mt_run)
                );
                action = on_iteration(ctx);
                if action == IterationAction.ABORT {
                    yield StreamEvent(
                        event_type="steps_done",
                        data={"iterations": iter_count - 1, "reason": "aborted"}
                    );
                    if last_result {
                        yield StreamEvent(
                            event_type="chunk", data={"content": last_result}
                        );
                    }
                    break;
                }
                if action == IterationAction.ABORT_WITH_SUMMARY {
                    yield StreamEvent(
                        event_type="steps_done",
                        data={
                            "iterations": iter_count - 1,
                            "reason": "aborted_with_summary"
                        }
                    );
                    for token in self._stream_final_answer(mt_run) {
                        if token {
                            yield StreamEvent(
                                event_type="chunk", data={"content": token}
                            );
                        }
                    }
                    yield from _usage_step_events(mt_run, _usage_base);
                    break;
                }
            }

            if int(max_iters) > 0 and iter_count > int(max_iters) {
                yield StreamEvent(
                    event_type="steps_done",
                    data={"iterations": iter_count - 1, "reason": "max_iterations"}
                );
                for token in self._stream_final_answer(mt_run) {
                    if token {
                        yield StreamEvent(event_type="chunk", data={"content": token});
                    }
                }
                yield from _usage_step_events(mt_run, _usage_base);
                break;
            }

            import time as _time;
            _llm_t0 = _time.time();
            try {
                _stream_out: list[CompletionResult] = [];
                _emitted_deltas = False;
                _seen_resets = mt_run._stream_reset_count;
                for _tok in self.dispatch_streaming_with_tools(mt_run, _stream_out) {
                    if mt_run._stream_reset_count != _seen_resets {
                        _seen_resets = mt_run._stream_reset_count;
                        yield StreamEvent(
                            event_type="stream_reset",
                            data={"scope": "thought", "iteration": iter_count}
                        );
                    }
                    while mt_run._tool_arg_deltas {
                        _d = mt_run._tool_arg_deltas.pop(0);
                        _emitted_deltas = True;
                        yield StreamEvent(
                            event_type="tool_call_delta",
                            data={
                                "call_id": _d.get("call_id", ""),
                                "tool": _d.get("tool", ""),
                                "arg_fragment": _d.get("arg_fragment", ""),
                                "index": _d.get("index", 0),
                                "truncated": _d.get("truncated", False),
                                "iteration": iter_count
                            }
                        );
                    }
                    if _tok {
                        yield StreamEvent(
                            event_type="thought",
                            data={
                                "content": _tok,
                                "iteration": iter_count,
                                "streaming": True
                            }
                        );
                    }
                }

                if mt_run._stream_reset_count != _seen_resets {
                    _seen_resets = mt_run._stream_reset_count;
                    yield StreamEvent(
                        event_type="stream_reset",
                        data={"scope": "thought", "iteration": iter_count}
                    );
                }
                while mt_run._tool_arg_deltas {
                    _d = mt_run._tool_arg_deltas.pop(0);
                    _emitted_deltas = True;
                    yield StreamEvent(
                        event_type="tool_call_delta",
                        data={
                            "call_id": _d.get("call_id", ""),
                            "tool": _d.get("tool", ""),
                            "arg_fragment": _d.get("arg_fragment", ""),
                            "index": _d.get("index", 0),
                            "truncated": _d.get("truncated", False),
                            "iteration": iter_count
                        }
                    );
                }
                resp = _stream_out[0];
            } except litellm.exceptions.ContextWindowExceededError {
                if _emitted_deltas {
                    _emitted_deltas = False;
                    yield StreamEvent(
                        event_type="stream_reset",
                        data={"scope": "thought", "iteration": iter_count}
                    );
                }
                mt_run._tool_arg_deltas = [];
                resp = self._emergency_compact_retry(mt_run, just_compacted, _cp);
                just_compacted = True;
            } except OutputConversionError {
                if _emitted_deltas {
                    _emitted_deltas = False;
                    yield StreamEvent(
                        event_type="stream_reset",
                        data={"scope": "thought", "iteration": iter_count}
                    );
                }
                mt_run._tool_arg_deltas = [];
                recovery_resp = self._attempt_recovery(mt_run);
                if recovery_resp is None {
                    raise;
                }
                yield from self._yield_recovery_result(
                    recovery_resp, iter_count, mt_run, _usage_base
                );
                break;
            }
            _llm_ms = int((_time.time() - _llm_t0) * 1000);

            usage: dict[str, any] = resp.usage or {};
            total_tokens += int(
                usage.get("total_tokens", 0)
                    if isinstance(usage, dict)
                    else getattr(usage, "total_tokens", 0)
            );

            just_compacted = self._maybe_compact(mt_run, usage, just_compacted, _cp);

            yield StreamEvent(
                event_type="llm_timing",
                data={"duration_ms": _llm_ms, "iteration": iter_count}
            );
            yield from _usage_step_events(mt_run, _usage_base);
            _usage_base = len(mt_run._usage_history);

            if resp.tool_calls {
                non_finish_calls: list[ToolCall] = [];
                finish_tc: (ToolCall | None) = None;
                for tc in resp.tool_calls {
                    if tc.is_finish_call() {
                        finish_tc = tc;
                        break;
                    }
                    non_finish_calls.append(tc);
                }

                if non_finish_calls {
                    max_result_len = int(
                        mt_run.call_params.get("max_tool_result_length")
                            or self.call_params.get("max_tool_result_length")
                            or _call_params_config.get("max_tool_result_length")
                            or 500
                    );

                    batches = (
                        [non_finish_calls]
                            if _should_parallelize(mt_run)
                            else [[tc] for tc in non_finish_calls]
                    );

                    for batch in batches {
                        for btc in batch {
                            yield StreamEvent(
                                event_type="tool_call",
                                data={
                                    "tool": btc.tool.get_name(),
                                    "args": btc.args,
                                    "call_id": btc.call_id,
                                    "iteration": iter_count
                                }
                            );
                        }

                        raw_results: list[tuple[ToolCall, Message, float]] = [];
                        for bres in dispatch_batch(batch) {
                            btc: ToolCall = bres[0];
                            result_msg: Message = bres[1];
                            tool_ms: float = bres[2];
                            truncated_result = content_preview(
                                result_msg.content, max_result_len
                            );
                            last_tool = btc.tool.get_name();
                            last_result = truncated_result;
                            yield StreamEvent(
                                event_type="tool_result",
                                data={
                                    "tool": btc.tool.get_name(),
                                    "result": truncated_result,
                                    "call_id": btc.call_id,
                                    "iteration": iter_count
                                }
                            );
                            yield StreamEvent(
                                event_type="tool_timing",
                                data={
                                    "tool": btc.tool.get_name(),
                                    "duration_ms": tool_ms,
                                    "call_id": btc.call_id,
                                    "iteration": iter_count
                                }
                            );
                            raw_results.append((btc, result_msg, tool_ms));
                        }

                        ordered: dict[int, tuple[ToolCall, Message, float]] = {};
                        for r in raw_results {
                            idx = _index_by_identity(batch, r[0]);
                            ordered[idx] = r;
                        }
                        for i in range(len(batch)) {
                            mt_run.add_message(ordered[i][1]);
                        }
                    }
                }

                if finish_tc {
                    try {
                        finish_msg = finish_tc();
                        final_output = finish_tc.get_output();
                    } except FinishToolError as e {
                        mt_run.add_message(
                            _error_tool_call(finish_tc.call_id, "finish_tool", str(e))()
                        );
                        continue;
                    }
                    mt_run.add_message(finish_msg);

                    mt_run._final_output = final_output;
                    mt_run._has_final_output = True;
                    yield StreamEvent(
                        event_type="steps_done", data={"iterations": iter_count}
                    );

                    if mt_run.resp_type is None or mt_run.resp_type is str {
                        for token in self._stream_final_answer(mt_run) {
                            if token {
                                yield StreamEvent(
                                    event_type="chunk", data={"content": token}
                                );
                            }
                        }
                        yield from _usage_step_events(mt_run, _usage_base);
                    }
                    break;
                }
            } else {
                recovery_resp = self._attempt_recovery(mt_run);
                if recovery_resp is None {
                    yield StreamEvent(
                        event_type="steps_done", data={"iterations": iter_count}
                    );
                    final_answer = str(resp.output) if resp.output is not None else "";
                    if final_answer {
                        yield StreamEvent(
                            event_type="chunk", data={"content": final_answer}
                        );
                    }
                    break;
                }
                yield from self._yield_recovery_result(
                    recovery_resp, iter_count, mt_run, _usage_base
                );
                break;
            }
        }
    }

    yield StreamEvent(event_type="usage", data=_aggregate_usage(mt_run._usage_history));

    mt_run.write_back_conversation();
}
