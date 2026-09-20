def _copy_for_compaction(model: BaseLLM) -> BaseLLM {
    import copy;
    m = copy.copy(model);
    m.call_params = {"compaction_enabled": False};
    return m;
}

def _default_compact(
    messages: list[any],
    keep_recent: int,
    model: BaseLLM,
    parent_mt_run: MTRuntime | None = None
) -> list[any] {
    if len(messages) < 4 {
        return messages;
    }

    kept_tail: list[any] = [];
    assistant_rounds = 0;
    i = len(messages) - 1;
    while i >= 2 and assistant_rounds < keep_recent {
        msg = messages[i];
        role = msg.get("role") if isinstance(msg, dict) else msg?.role;
        if str(role) == "assistant" {
            assistant_rounds += 1;
        }
        kept_tail.insert(0, msg);
        i -= 1;
    }

    compact_slice = messages[2:i + 1];
    if not compact_slice {
        return messages;
    }

    lines: list[str] = [];
    for msg in compact_slice {
        if isinstance(msg, dict) {
            role = msg.get("role", "");
            content = msg.get("content") or "";
            if isinstance(content, list) {
                content = " ".join(
                    p.get("text", "") if isinstance(p, dict) else str(p)
                    for p in content
                );
            }
            if str(role) == "assistant" and not content {
                tool_calls: any = msg.get("tool_calls") or [];
                if tool_calls {
                    descs: list[str] = [];
                    for tc in tool_calls {
                        fn = tc.get("function", {})
                            if isinstance(tc, dict)
                            else (tc?.function or {});
                        name = (
                            fn.get("name", "?") if isinstance(fn, dict) else fn?.name
                        )
                            or "?";
                        args = (
                            fn.get("arguments", "")
                                if isinstance(fn, dict)
                                else fn?.arguments
                        )
                            or "";
                        descs.append(f"{name}({args})");
                    }
                    content = "called: " + "; ".join(descs);
                }
            }
            lines.append(f"[{role}] {content}");
        } else {
            lines.append(str(msg));
        }
    }
    history_text = "\n".join(lines);
    summary_prompt = (
        "Summarise the following agent tool-call history concisely. "
        "Preserve key findings, decisions, and intermediate results that "
        "may be needed to complete the ongoing task. Output plain text only.\n\n"
        + history_text
    );
    comp_mt_run = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="You are a concise summariser."),
            Message(role=MessageRole.USER, content=summary_prompt)
        ],
        tools=[],
        resp_type=str,
        stream=False,
        call_params={"compaction_enabled": False},
        mtir=None,
        _call_kind="compaction"
    );
    summary = str(model.invoke(comp_mt_run));
    if parent_mt_run is not None {
        parent_mt_run._usage_history.extend(comp_mt_run._usage_history);
    }
    summary_msg = {
        "role": "user",
        "content": f"[Compacted context summary]\n{summary}"
    };
    return [messages[0], messages[1], summary_msg] + kept_tail;
}

impl BaseLLM._get_ctx_window(call_params: dict[str, any]) -> int {
    `override = int(
        call_params.get("ctx_window")
            or self.ctx_window
            or get_byllm_config().get_compaction_config().get("ctx_window", 0)
            or 0
    );
    if `override > 0 {
        return `override;
    }
    return _litellm_ctx_window(self.model_name);
}

impl BaseLLM._resolve_compaction_params(mt_run: MTRuntime) -> dict[str, any] {
    comp_cfg = get_byllm_config().get_compaction_config();
    enabled = bool(
        mt_run.call_params.get("compaction_enabled")
            if mt_run.call_params.get("compaction_enabled") is not None
            else comp_cfg.get("enabled", True)
    );
    _raw_threshold = (
        mt_run.call_params.get("threshold_ratio")
            if mt_run.call_params.get("threshold_ratio") is not None
            else self.call_params.get("threshold_ratio")
                if self.call_params.get("threshold_ratio") is not None
                else None
    );
    threshold = float(str(_raw_threshold))
        if _raw_threshold is not None
        else float(comp_cfg.get("threshold_ratio", 0.80));
    _raw_keep_recent = (
        mt_run.call_params.get("keep_recent_iterations")
            if mt_run.call_params.get("keep_recent_iterations") is not None
            else self.call_params.get("keep_recent_iterations")
                if self.call_params.get("keep_recent_iterations") is not None
                else None
    );
    keep_recent = int(str(_raw_keep_recent))
        if _raw_keep_recent is not None
        else int(comp_cfg.get("keep_recent_iterations", 3));
    _raw_model = (
        mt_run.call_params.get("compaction_model")
        or self.call_params.get("compaction_model")
        or comp_cfg.get("compaction_model")
    );
    model: str | None = str(_raw_model) if _raw_model else None;
    return {
        "enabled": enabled,
        "threshold": threshold,
        "keep_recent": keep_recent,
        "model": model,
        "ctx_window": self._get_ctx_window(mt_run.call_params)
    };
}

impl BaseLLM._maybe_compact(
    mt_run: MTRuntime, usage: object, just_compacted: bool, cp: dict[str, any]
) -> bool {
    ctx_window = int(cp["ctx_window"]);
    if not (bool(cp["enabled"]) and ctx_window > 0) {
        return just_compacted;
    }
    comp_threshold = float(cp["threshold"]);
    prompt_tokens = int(
        usage.get("prompt_tokens", 0)
            if isinstance(usage, dict)
            else usage?.prompt_tokens or 0
    );
    if prompt_tokens > 0 and prompt_tokens / ctx_window >= comp_threshold {
        if just_compacted {
            raise CompactionNotEffectiveError(
                f"{prompt_tokens}/{ctx_window} tokens "
                f"({prompt_tokens / ctx_window:.0%}) still at or above threshold "
                f"{comp_threshold:.0%} after compaction - provide a custom "
                "on_compaction hook, increase ctx_window, or switch to a model "
                "with a larger context window."
            );
        }
        logger.info(
            f"byLLM compaction: {prompt_tokens}/{ctx_window} tokens "
            f"({prompt_tokens / ctx_window:.0%}) >= threshold {comp_threshold:.0%}. "
            "Compacting message history."
        );
        self._compact_messages(mt_run, int(cp["keep_recent"]), cp["model"]);
        return True;
    }
    return False;
}

impl BaseLLM._emergency_compact_retry(
    mt_run: MTRuntime, just_compacted: bool, cp: dict[str, any]
) -> CompletionResult {
    if not bool(cp["enabled"]) {
        raise;
    }
    if just_compacted {
        raise CompactionNotEffectiveError(
            "Context window exceeded again after emergency compaction - "
            "provide a custom on_compaction hook, increase ctx_window, "
            "or switch to a model with a larger context window."
        );
    }
    logger.warning(
        "byLLM compaction: context window exceeded, triggering emergency compaction."
    );
    self._compact_messages(mt_run, int(cp["keep_recent"]), cp["model"]);
    return self.dispatch_no_streaming(mt_run);
}

impl BaseLLM._compact_messages(
    mt_run: MTRuntime, keep_recent: int, comp_model: str | None
) -> None {
    on_compaction = (
        mt_run.call_params.get("on_compaction") or self.call_params.get("on_compaction")
    );
    original_len = len(mt_run.messages);
    msg_dicts = mt_run.get_msg_list();
    if on_compaction {
        compacted = on_compaction(msg_dicts, keep_recent);
        if not isinstance(compacted, list) or len(compacted) < 2 {
            got_type = type(compacted).__name__;
            got_len = len(compacted) if isinstance(compacted, list) else "N/A";
            raise ConfigurationError(
                "on_compaction hook must return a list with at least 2 messages "
                f"(system + user task). Got: {got_type} of length {got_len}."
            );
        }
    } else {
        if comp_model {
            model_for_compaction: BaseLLM = Model(
                model_name=comp_model,
                api_key=self.api_key,
                config=self.config,
                call_params={"compaction_enabled": False}
            );
        } else {
            model_for_compaction = _copy_for_compaction(self);
        }
        compacted = _default_compact(
            msg_dicts, keep_recent, model_for_compaction, mt_run
        );
    }
    removed = original_len - len(compacted);
    if removed == 0 and original_len >= 4 {
        raise CompactionNotEffectiveError(
            "Compaction produced no reduction in message history - "
            "check on_compaction hook or compaction model."
        );
    }
    mt_run.messages = compacted;
    logger.info(
        f"byLLM compaction: reduced message list from {original_len} to {len(
            compacted
        )} "
        f"({removed} messages replaced with summary)"
    );
}
