impl BaseLLM.make_model_params(mt_run: MTRuntime) -> dict[str, any] {
    default_temp = _call_params_config.get("temperature");
    default_max_tokens = _call_params_config.get("max_tokens");

    agent_metadata = {};
    try {
        agent_metadata = {
            "jac_invocation_id": mt_run?._invocation_id,
            "jac_parent_invocation_id": mt_run?._parent_invocation_id,
            "jac_caller_name": mt_run.mtir.caller.__name__ if mt_run.mtir else None,

        };
    } except Exception as e {
        logger.debug(f"agent_metadata build failed: {e}");
    }

    messages = mt_run.get_msg_list();

    messages = reroute_tool_images_to_user_message(messages);
    tools = mt_run.get_tool_list() or None;

    if _should_parallelize(mt_run)
        and tools
        and mt_run.call_params.get("parallel_hint", True)
        and messages
        and len(messages) > 0 {
        annotated: list[dict[str, any]] = [];
        serial_names: list[str] = [];
        for (i, schema) in enumerate(tools) {
            tool_obj = mt_run.tools[i] if i < len(mt_run.tools) else None;
            is_serial = bool(getattr(tool_obj, "serialize", False));
            is_finish = tool_obj.is_finish_tool() if tool_obj else False;
            if is_finish {
                annotated.append(schema);
            } else {
                fn = schema.get("function", {});
                desc = fn.get("description", "");
                if is_serial {
                    serial_names.append(fn.get("name", "unknown"));
                    tag = " [SEQUENTIAL: has side-effects - must be called alone, never batch with other tools]";
                } else {
                    tag = " [PARALLEL-SAFE: can be batched with other independent tools in one response]";
                }
                annotated.append(
                    {** schema, "function": {** fn, "description": desc + tag}}
                );
            }
        }
        tools = annotated;

        first_msg = messages[0];
        if isinstance(first_msg, dict) and first_msg.get("role") == "system" {
            content = first_msg.get("content", "");
            if isinstance(content, str) and _PARALLEL_TOOL_HINT not in content {
                hint = _PARALLEL_TOOL_HINT;

                hint += (
                    "\n\n**Intelligent tool scheduling rules:**"
                    "\nBATCH in one response (parallel) when:"
                    "\n - You already know ALL required arguments for every tool"
                    "\n - No tool in the group needs another tool's output as input"
                    "\n - No two tools in the group modify the same resource"
                    "\nSEPARATE into different responses (sequential) when:"
                    "\n - A tool's argument depends on another tool's return value"
                    "\n - Two tools write to the same file or shared state"
                    "\n - A tool is labeled [SEQUENTIAL] in its description"
                    "\n\nKEY TEST: For each tool ask - 'Can I fill in ALL of this tool's arguments RIGHT NOW"
                    " without waiting for any other tool's result?' YES for all → batch. NO for any → separate it."
                );

                if serial_names {
                    hint += (
                        f"\n\nTools that must ALWAYS run alone (never batch): {serial_names}"
                    );
                }

                messages = list(messages);
                messages[0] = {** first_msg, "content": content + hint};
            }
        }
    }

    if _is_prompt_caching_eligible(self.model_name) {
        _apply_prompt_caching(messages, tools);
    }

    params = {
        "model": self.model_name,
        "api_key": self.api_key or None,
        "api_base": (
            self.config.get("base_url")
            or self.config.get("host")
            or self.config.get("api_base")
            or self.api_base
            or _model_config.get("base_url")
        ),
        "messages": messages,
        "tools": tools,
        "response_format": mt_run.get_output_schema(),
        "max_tokens": self.call_params.get("max_tokens", default_max_tokens),
        "metadata": agent_metadata,

    };

    resolved_temp = self.call_params.get("temperature", default_temp);
    if resolved_temp is not None {
        params["temperature"] = resolved_temp;
    }

    if "tool_choice" in mt_run.call_params {
        params["tool_choice"] = mt_run.call_params["tool_choice"];
    }

    params = inject_schema_hint(params);

    if not self.supports_native_tools {
        params = inject_tool_hint(params);
    }

    if mt_run.stream {
        import httpx;
        params["timeout"] = httpx.Timeout(
            connect=_streaming_config.get("connect_timeout", 30.0),
            read=_streaming_config.get("read_timeout", 90.0),
            write=_streaming_config.get("write_timeout", 30.0),
            pool=_streaming_config.get("pool_timeout", 30.0)
        );
    }
    return params;
}

impl BaseLLM.log_info(message: str) -> None {
    verbose = self.config.get("verbose", _model_config.get("verbose", False));
    if bool(verbose) {
        logger.info(message);
    }
}

impl BaseLLM.format_prompt(params: dict[str, any]) -> str {
    MAGENTA = "\033[95m";
    RESET = "\033[0m";
    log_params = params.copy();
    if log_params.get("api_key") {
        key = log_params["api_key"];
        if len(key) <= 1 {
            log_params["api_key"] = "*";
        } elif len(key) < 4 {
            log_params["api_key"] = "*" * (len(key) - 1) + key[-1:];
        } else {
            log_params["api_key"] = "*" * (len(key) - 4) + key[-4:];
        }
    }
    def _msg_content(m: object) -> object {
        if isinstance(m, dict) {
            return m.get("content");
        }
        return m?.content;
    }
    msgs = log_params["messages"];
    user_content = _msg_content(msgs[1]);
    log = f"""
    {MAGENTA}[SYSTEM]{RESET}
    {_msg_content(msgs[0])}
    {MAGENTA}[USER]{RESET}
    {user_content[0]['text'] if isinstance(user_content, list) else user_content}
    {MAGENTA}[TOOL]{RESET}
    {_msg_content(msgs[3]) if len(msgs) > 3 else "No tools provided."}
    {" "}
    {MAGENTA}[TOOLS]{RESET}
    {json.dumps(log_params.get("tools"), indent=2, ensure_ascii=False)
        if log_params.get("tools")
        else ""}
    {MAGENTA}[RESPONSE FORMAT]{RESET}
    {json.dumps(log_params.get("response_format"), indent=2, ensure_ascii=False)
        if log_params.get("response_format") is not None
        else "None"}""";
    return log;
}

impl BaseLLM.dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    params = self.make_model_params(mt_run);

    log_params = self.format_prompt(params);
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    while True {
        try {
            response = self.model_call_no_stream(params);
            break;
        } except Exception as e {
            if _is_transient_error(e)
                and attempt < self._resolve_stream_retries(mt_run) {
                attempt += 1;
                self.log_info(
                    f"Transient LLM error ({type(e).__name__}); "
                    f"retry {attempt} on {self.model_name}"
                );
                _retry_sleep(attempt);
                continue;
            }

            self.log_info(f"Calling LLM: {self.model_name} with params: {log_params}");
            raise;
        }
    }

    actual_model = response.get("model", self.model_name);
    self.log_info(f"Calling LLM: {actual_model} with params: {log_params}");

    message = coerce_message_dict(response.get("choices", [])[0].get("message"));

    if not self.supports_native_tools {
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    damaged_ids = _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content = message.get("content") or "";
    assert isinstance(output_content, str);
    self.log_info(f"LLM call completed with response: {output_content}");
    finish_reason = str(
        (response.get("choices") or [{}])[0].get("finish_reason") or ""
    );

    truncated_ids = _truncated_call_ids(message, finish_reason);
    tool_calls: list[ToolCall] = [];
    _tc_raw: any = (message or {}).get("tool_calls") or [];
    tool_calls_list: list[any] = _tc_raw if isinstance(_tc_raw, list) else [];
    tool_calls = _parse_tool_calls(mt_run, tool_calls_list, truncated_ids, damaged_ids);

    output_value = mt_run.parse_response(output_content)
        if not tool_calls_list
        else output_content;
    usage_data = response.get("usage", {});
    _attach_call_cost(usage_data, self.model_name, response);
    _record_usage(mt_run, usage_data, actual_model, finish_reason=finish_reason);
    return CompletionResult(
        output=output_value, tool_calls=tool_calls, usage=usage_data
    );
}

impl BaseLLM.dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None] {
    params = self.make_model_params(mt_run);

    log_params = self.format_prompt(params);
    self.log_info(f"Calling LLM: {self.model_name} with params:\n{log_params}");
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    usage_base = len(mt_run._usage_history);
    stream_model: str = self.model_name;
    while True {
        finish_reason = "";
        try {
            response = self.model_call_with_stream(params);
            for chunk in response {
                stream_model = chunk?.model or stream_model;
                if chunk?.choices and chunk?.choices?[0]?.finish_reason {
                    finish_reason = str(chunk?.choices?[0]?.finish_reason);
                }
                chunk_usage = chunk?.usage;
                if chunk_usage {
                    chunk_model: str = chunk?.model or self.model_name;
                    _attach_call_cost(chunk_usage, chunk_model);
                    _record_usage(
                        mt_run, chunk_usage, chunk_model, finish_reason=finish_reason
                    );
                }
                if chunk?.choices and chunk?.choices?[0]?.delta {
                    delta = chunk?.choices?[0]?.delta;
                    yield delta?.content or "";
                }
            }
            break;
        } except Exception as e {
            if self._should_retry_stream(mt_run, e, attempt, usage_base) {
                attempt += 1;
                _retry_sleep(attempt);
                continue;
            }
            raise;
        }
    }

    if len(mt_run._usage_history) == usage_base {
        _record_usage(mt_run, {}, stream_model, finish_reason=finish_reason);
    }
}

impl BaseLLM.dispatch_streaming_with_tools(
    mt_run: MTRuntime, out: list[CompletionResult]
) -> Generator[str, None, None] {
    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.log_info(
        f"Calling LLM (streaming): {self.model_name} with params:\n{log_params}"
    );
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    chunks: list[any] = [];
    content_buf = "";
    no_stream = False;
    finish_reason = "";
    attempt = 0;
    while True {
        chunks = [];
        content_buf = "";

        mt_run._tool_arg_deltas = [];
        settings = _tool_stream_settings(mt_run);
        stream_args = bool(settings.get("enabled", False));
        coalescer = _ToolDeltaCoalescer(
            out=mt_run._tool_arg_deltas,
            min_chars=int(settings.get("min_chars", _TOOL_DELTA_MIN_CHARS)),
            min_interval=float(
                settings.get("min_interval", _TOOL_DELTA_MIN_INTERVAL_S)
            ),
            max_per_call=int(settings.get("max_per_call", _TOOL_DELTA_MAX_PER_CALL))
        );
        try {
            _stream_resp = self.model_call_with_stream(params);
            for chunk in _stream_resp {
                chunks.append(chunk);
                pending_before = len(mt_run._tool_arg_deltas);
                if stream_args {
                    for _frag in _tool_call_fragments(chunk) {
                        coalescer.observe(_frag);
                    }
                }
                delta_content = "";
                if chunk?.choices and chunk?.choices?[0]?.delta {
                    delta_content = chunk?.choices?[0]?.delta?.content or "";
                } elif isinstance(chunk, dict) {
                    _choices: any = chunk.get("choices") or [];
                    if _choices {
                        delta_content = str(
                            (_choices[0].get("delta") or {}).get("content") or ""
                        );
                    }
                }
                if delta_content {
                    content_buf += str(delta_content);
                    yield str(delta_content);
                } elif len(mt_run._tool_arg_deltas) > pending_before {
                    yield "";
                }
            }
            if stream_args {
                coalescer.flush();
            }
            break;
        } except NotImplementedError {
            no_stream = True;
            break;
        } except Exception as e {
            if self._should_retry_stream(mt_run, e, attempt) {
                attempt += 1;
                _retry_sleep(attempt);
                continue;
            }
            raise;
        }
    }
    if no_stream {
        out.append(self.dispatch_no_streaming(mt_run));
        return;
    }

    message: (dict[str, any] | None) = None;
    usage_data: dict[str, any] = {};
    actual_model = self.model_name;
    try {
        rebuilt = _rebuild_stream_chunks(chunks, _stream_resp?.logging_obj);
        if rebuilt {
            message = coerce_message_dict(rebuilt.get("choices", [])[0].get("message"));
            usage_data = rebuilt.get("usage", {}) or {};
            actual_model = rebuilt.get("model", self.model_name);
            _attach_call_cost(usage_data, actual_model, rebuilt);
            finish_reason = str(
                rebuilt.get("choices", [])[0].get("finish_reason") or ""
            );
        }
    } except Exception as e {
        logger.debug(f"stream_chunk_builder failed, using accumulated text: {e}");
        message = None;
    }
    if message is None {
        message = {"role": "assistant", "content": content_buf};
    }

    has_native_tool_calls = bool((message or {}).get("tool_calls"));
    if (not self.supports_native_tools)
        or (mt_run.tools and not has_native_tool_calls) {
        if not has_native_tool_calls and not isinstance(message, dict) {
            message = {"role": "assistant", "content": content_buf};
        }
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    damaged_ids = _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content = message.get("content") or "";
    assert isinstance(output_content, str);

    truncated_ids = _truncated_call_ids(message, finish_reason);
    tool_calls: list[ToolCall] = [];
    _tc_raw: any = (message or {}).get("tool_calls") or [];
    tool_calls_list: list[any] = _tc_raw if isinstance(_tc_raw, list) else [];
    tool_calls = _parse_tool_calls(mt_run, tool_calls_list, truncated_ids, damaged_ids);
    output_value = mt_run.parse_response(output_content)
        if not tool_calls_list
        else output_content;
    _record_usage(mt_run, usage_data, actual_model, finish_reason=finish_reason);
    out.append(
        CompletionResult(output=output_value, tool_calls=tool_calls, usage=usage_data)
    );
}

impl BaseLLM.adispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    while True {
        try {
            response = await self.model_call_no_stream_async(params);
            break;
        } except Exception as e {
            if _is_transient_error(e)
                and attempt < self._resolve_stream_retries(mt_run) {
                attempt += 1;
                self.log_info(
                    f"Transient LLM error ({type(e).__name__}); "
                    f"retry {attempt} on {self.model_name}"
                );
                await _aretry_sleep(attempt);
                continue;
            }
            self.log_info(f"Calling LLM: {self.model_name} with params: {log_params}");
            raise;
        }
    }
    actual_model = response.get("model", self.model_name);
    self.log_info(f"Calling LLM: {actual_model} with params: {log_params}");
    message = coerce_message_dict(response.get("choices", [])[0].get("message"));

    if not self.supports_native_tools {
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    damaged_ids = _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content = message.get("content") or "";
    assert isinstance(output_content, str);
    self.log_info(f"LLM call completed with response: {output_content}");
    finish_reason = str(
        (response.get("choices") or [{}])[0].get("finish_reason") or ""
    );

    truncated_ids = _truncated_call_ids(message, finish_reason);
    tool_calls: list[ToolCall] = [];
    _tc_raw: any = (message or {}).get("tool_calls") or [];
    tool_calls_list: list[any] = _tc_raw if isinstance(_tc_raw, list) else [];
    tool_calls = _parse_tool_calls(mt_run, tool_calls_list, truncated_ids, damaged_ids);
    output_value = mt_run.parse_response(output_content)
        if not tool_calls_list
        else output_content;
    usage_data = response.get("usage", {});
    _attach_call_cost(usage_data, self.model_name, response);
    _record_usage(mt_run, usage_data, actual_model, finish_reason=finish_reason);
    return CompletionResult(
        output=output_value, tool_calls=tool_calls, usage=usage_data
    );
}

impl BaseLLM.adispatch_streaming(mt_run: MTRuntime) -> AsyncIterator[str] {
    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.log_info(f"Calling LLM: {self.model_name} with params:\n{log_params}");
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    usage_base = len(mt_run._usage_history);
    stream_model: str = self.model_name;
    while True {
        finish_reason = "";
        try {
            response = await self.model_call_with_stream_async(params);
            async for chunk in response {
                stream_model = chunk?.model or stream_model;
                if chunk?.choices and chunk?.choices?[0]?.finish_reason {
                    finish_reason = str(chunk?.choices?[0]?.finish_reason);
                }
                chunk_usage = chunk?.usage;
                if chunk_usage {
                    chunk_model: str = chunk?.model or self.model_name;
                    _attach_call_cost(chunk_usage, chunk_model);
                    _record_usage(
                        mt_run, chunk_usage, chunk_model, finish_reason=finish_reason
                    );
                }
                if chunk?.choices and chunk?.choices?[0]?.delta {
                    delta = chunk?.choices?[0]?.delta;
                    yield str(delta?.content or "");
                }
            }
            break;
        } except Exception as e {
            if self._should_retry_stream(mt_run, e, attempt, usage_base) {
                attempt += 1;
                await _aretry_sleep(attempt);
                continue;
            }
            raise;
        }
    }

    if len(mt_run._usage_history) == usage_base {
        _record_usage(mt_run, {}, stream_model, finish_reason=finish_reason);
    }
}

impl BaseLLM.model_call_no_stream(params: dict[str, any]) -> dict[str, any] {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call without streaming."
    );
}

impl BaseLLM.model_call_with_stream(params: dict[str, any]) -> Iterable[object] {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call with streaming."
    );
}

impl BaseLLM.model_call_no_stream_async(params: dict[str, any]) -> dict[str, any] {
    import asyncio;
    return await asyncio.to_thread(self.model_call_no_stream, params);
}

impl BaseLLM.model_call_with_stream_async(
    params: dict[str, any]
) -> AsyncIterator[object] {
    import asyncio;

    def _next_chunk(gen: Generator[object, None, None]) -> tuple[bool, object] {
        try {
            return (True, next(gen));
        } except StopIteration {
            return (False, None);
        }
    }
    async def _iter -> AsyncGenerator[object, None] {
        gen = iter(await asyncio.to_thread(self.model_call_with_stream, params));
        while True {
            (has_value, chunk) = await asyncio.to_thread(_next_chunk, gen);
            if not has_value {
                break;
            }
            yield chunk;
        }
    }
    return _iter();
}
