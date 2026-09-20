def _is_transient_error(exc: object) -> bool {
    return isinstance(
        exc,
        (
            litellm.Timeout,
            litellm.APIConnectionError,
            litellm.InternalServerError,
            litellm.ServiceUnavailableError
        )
    );
}

def _retry_sleep(attempt: int) {
    base = _streaming_config.get("retry_backoff", 1.0);
    time.sleep(min(base * (2 ** max(0, attempt - 1)), 10.0));
}

async def _aretry_sleep(attempt: int) {
    import asyncio;
    base = _streaming_config.get("retry_backoff", 1.0);
    await asyncio.sleep(min(base * (2 ** max(0, attempt - 1)), 10.0));
}

impl BaseLLM._resolve_output_attempts(mt_run: MTRuntime) -> int {
    max_retries = mt_run.call_params.get("max_output_retries");
    if max_retries is None {
        max_retries = self.call_params.get("max_output_retries");
    }
    if max_retries is None {
        max_retries = _call_params_config.get("max_output_retries");
    }
    if max_retries is None {
        max_retries = 3;
    }
    return 1 + max(0, int(max_retries));
}

impl BaseLLM._resolve_stream_retries(mt_run: MTRuntime) -> int {
    num_retries = mt_run.call_params.get("stream_num_retries");
    if num_retries is None {
        num_retries = self.call_params.get("stream_num_retries");
    }
    if num_retries is None {
        num_retries = _streaming_config.get("num_retries");
    }
    if num_retries is None {
        num_retries = 2;
    }
    return max(0, int(num_retries));
}

impl BaseLLM._invoke_typed_retry(mt_run: MTRuntime) -> object {
    max_attempts = self._resolve_output_attempts(mt_run);
    base_msgs = list(mt_run.messages);
    base_scaffolding = list(mt_run._scaffolding_ids);
    attempt = 0;
    last_reason = "";
    last_output = "";
    try {
        while True {
            attempt += 1;
            if attempt > 1 {
                self._typed_retry_reset(
                    mt_run, base_msgs, base_scaffolding, last_reason, last_output
                );
            }
            try {
                result = self._invoke_react_loop(mt_run);
            } except OutputConversionError as e {
                (last_reason, last_output) = self._parse_failure_feedback(
                    attempt, max_attempts, e
                );
                if attempt >= max_attempts {
                    raise self._typed_retry_exhausted(attempt, e, last_output) from e;
                }
                continue;
            }
            if self._structured_output_ok(mt_run, result) {
                return result;
            }
            (last_err, last_reason, last_output) = self._nonconforming_feedback(
                attempt, max_attempts, mt_run, result
            );
            if attempt >= max_attempts {
                raise self._typed_retry_exhausted(
                    attempt, last_err, last_output
                ) from last_err;
            }
        }
    } finally {
        mt_run.write_back_conversation();
    }
}

impl BaseLLM._ainvoke_typed_retry(mt_run: MTRuntime) -> object {
    max_attempts = self._resolve_output_attempts(mt_run);
    base_msgs = list(mt_run.messages);
    base_scaffolding = list(mt_run._scaffolding_ids);
    attempt = 0;
    last_reason = "";
    last_output = "";
    try {
        while True {
            attempt += 1;
            if attempt > 1 {
                self._typed_retry_reset(
                    mt_run, base_msgs, base_scaffolding, last_reason, last_output
                );
            }
            try {
                result = (await self.adispatch_no_streaming(mt_run)).output;
            } except OutputConversionError as e {
                (last_reason, last_output) = self._parse_failure_feedback(
                    attempt, max_attempts, e
                );
                if attempt >= max_attempts {
                    raise self._typed_retry_exhausted(attempt, e, last_output) from e;
                }
                continue;
            }
            if self._structured_output_ok(mt_run, result) {
                return result;
            }
            (last_err, last_reason, last_output) = self._nonconforming_feedback(
                attempt, max_attempts, mt_run, result
            );
            if attempt >= max_attempts {
                raise self._typed_retry_exhausted(
                    attempt, last_err, last_output
                ) from last_err;
            }
        }
    } finally {
        mt_run.write_back_conversation();
    }
}

impl BaseLLM._typed_retry_reset(
    mt_run: MTRuntime,
    base_msgs: list[any],
    base_scaffolding: list[any],
    reason: str,
    output: str
) -> None {
    mt_run.messages = list(base_msgs);
    mt_run._scaffolding_ids = list(base_scaffolding);
    mt_run._has_final_output = False;
    mt_run._final_output = None;
    mt_run.add_scaffolding_message(self._typed_retry_feedback(mt_run, reason, output));
}

impl BaseLLM._parse_failure_feedback(
    attempt: int, max_attempts: int, err: object
) -> tuple[str, str] {
    self.log_info(
        f"[byllm] typed-output attempt {attempt}/{max_attempts} failed to parse: {err}"
    );
    return (
        f"The output parser reported: {err}.",
        str(getattr(err, "raw_output", "") or "")
    );
}

impl BaseLLM._nonconforming_feedback(
    attempt: int, max_attempts: int, mt_run: MTRuntime, result: object
) -> tuple[OutputConversionError, str, str] {
    self.log_info(
        f"[byllm] typed-output attempt {attempt}/{max_attempts} "
            + "returned a non-conforming value; retrying"
    );
    err = OutputConversionError(
        f"LLM returned a non-conforming value for return type "
            + f"'{mt_run.resp_type}' (got '{type(result).__name__}'); the "
            + "response was likely empty or not valid JSON"
    );
    reason = (
        "The previous response was empty or did not contain a JSON "
        + "object (it could not be converted to the required type)."
    );
    return (err, reason, str(result));
}

impl BaseLLM._typed_retry_exhausted(
    attempts: int, cause: object, raw: str
) -> OutputConversionError {
    err = OutputConversionError(
        f"typed-output generation failed after {attempts} attempt(s) "
            + f"({attempts - 1} retries); last error: {cause}"
    );
    setattr(err, "raw_output", raw);
    return err;
}

impl BaseLLM._typed_retry_feedback(
    mt_run: MTRuntime, reason: str, prev_output: str
) -> Message {
    rt = mt_run.resp_type;
    type_name = rt.__name__
        if (rt is not None and hasattr(rt, "__name__"))
        else str(rt);

    schema = mt_run.get_typed_output_schema();
    schema_txt = (
        json.dumps(schema, ensure_ascii=False) if schema else "(schema unavailable)"
    );
    prev_block = f"Your previous response was:\n{prev_output}\n" if prev_output else "";
    return Message(
        role=MessageRole.USER,
        content=(
            f"Your previous response could not be used. {reason}\n"
            + prev_block
            + f"You MUST reply with ONLY a single JSON object that validates "
            + f"against this JSON schema for `{type_name}`:\n{schema_txt}\n"
            + "Output the raw JSON object only, with no explanation, no reasoning "
            + "text, no markdown code fences, nothing before or after the JSON."
        )
    );
}

impl BaseLLM._structured_output_ok(mt_run: MTRuntime, value: object) -> bool {
    rt = mt_run.resp_type;
    if rt is None or rt is str {
        return True;
    }
    if isinstance(value, str) {
        return value.strip() != "";
    }
    try {
        return isinstance(value, rt);
    } except Exception {
        return True;
    }
}

impl BaseLLM._should_retry_stream(
    mt_run: MTRuntime, e: Exception, attempt: int, usage_base: int = -1
) -> bool {
    if not (
        _is_transient_error(e) and attempt < self._resolve_stream_retries(mt_run)
    ) {
        return False;
    }
    if usage_base >= 0 {
        mt_run._usage_history = mt_run._usage_history[:usage_base];
    }
    mt_run._stream_reset_count += 1;
    self.log_info(
        f"Transient stream error ({type(e).__name__}); "
        f"retry {attempt + 1} on {self.model_name}"
    );
    return True;
}

impl BaseLLM._force_final_answer(mt_run: MTRuntime) -> object {
    final_instruction = Message(
        role=MessageRole.USER,
        content="Based on the tool calls and their results above, provide only your final answer.",
    );
    mt_run.add_scaffolding_message(final_instruction);
    original_call_kind = mt_run._call_kind;
    finish_tool_obj = mt_run.get_tool("finish_tool");
    original_tool_choice = mt_run.call_params.pop("tool_choice", None);
    if finish_tool_obj {
        mt_run.call_params["tool_choice"] = {
            "type": "function",
            "function": {"name": "finish_tool"}
        };
    }
    mt_run._call_kind = "final_answer_restream";
    try {
        final_resp = self.dispatch_no_streaming(mt_run);
        if final_resp.tool_calls {
            for tool_call in final_resp.tool_calls {
                if tool_call.is_finish_call() {
                    mt_run.add_scaffolding_message(tool_call());
                    return tool_call.get_output();
                }
            }
        }
        return str(final_resp.output) if final_resp.output else "";
    } finally {
        mt_run._call_kind = original_call_kind;
        mt_run.call_params.pop("tool_choice", None);
        if original_tool_choice is not None {
            mt_run.call_params["tool_choice"] = original_tool_choice;
        }
    }
}

impl BaseLLM._stream_final_answer(mt_run: MTRuntime) -> Generator[str, None, None] {
    final_instruction = Message(
        role=MessageRole.USER,
        content="Based on the tool calls and their results above, provide your final answer. "
        "Be comprehensive and synthesize all the information gathered.",
    );
    mt_run.add_scaffolding_message(final_instruction);

    original_call_kind = mt_run._call_kind;
    mt_run._call_kind = "final_answer_restream";

    original_tool_choice = mt_run.call_params.pop("tool_choice", None);
    mt_run.call_params["tool_choice"] = "none";
    accumulated: str = "";
    try {
        for token in self.dispatch_streaming(mt_run) {
            accumulated += token;
            yield token;
        }
    } finally {
        mt_run._call_kind = original_call_kind;
        mt_run.call_params.pop("tool_choice", None);
        if original_tool_choice is not None {
            mt_run.call_params["tool_choice"] = original_tool_choice;
        }

        if accumulated {
            mt_run.add_message(
                Message(role=MessageRole.ASSISTANT, content=accumulated)
            );
        }
    }
}

impl BaseLLM._attempt_recovery(mt_run: MTRuntime) -> CompletionResult | None {
    finish_tool_obj = mt_run.get_tool("finish_tool");
    if not finish_tool_obj or mt_run.resp_type is None or mt_run.resp_type is str {
        return None;
    }
    recovery_msg = Message(
        role=MessageRole.USER,
        content="You must use finish_tool to return your response. Call finish_tool now.",
    );
    mt_run.add_scaffolding_message(recovery_msg);
    original_call_kind = mt_run._call_kind;
    mt_run._call_kind = "recovery";
    original_tool_choice = mt_run.call_params.pop("tool_choice", None);
    mt_run.call_params["tool_choice"] = {
        "type": "function",
        "function": {"name": "finish_tool"}
    };
    try {
        return self.dispatch_no_streaming(mt_run);
    } finally {
        mt_run._call_kind = original_call_kind;
        mt_run.call_params.pop("tool_choice", None);
        if original_tool_choice is not None {
            mt_run.call_params["tool_choice"] = original_tool_choice;
        }
    }
}

impl BaseLLM._yield_recovery_result(
    recovery_resp: CompletionResult, iter_count: int, mt_run: MTRuntime, usage_base: int
) -> Generator[StreamEvent, None, None] {
    finish_found = False;
    if recovery_resp.tool_calls {
        for tool_call in recovery_resp.tool_calls {
            if tool_call.is_finish_call() {
                mt_run.add_message(tool_call());
                finish_found = True;
                break;
            }
        }
    }
    yield StreamEvent(event_type="steps_done", data={"iterations": iter_count});
    if finish_found {
        for token in self._stream_final_answer(mt_run) {
            if token {
                yield StreamEvent(event_type="chunk", data={"content": token});
            }
        }
    } elif recovery_resp.output {
        yield StreamEvent(
            event_type="chunk", data={"content": str(recovery_resp.output)}
        );
    }
    yield from _usage_step_events(mt_run, usage_base);
}
