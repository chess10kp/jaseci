def _is_prompt_caching_eligible(model_name: str) -> bool {
    pc_config = _byllm_config.get_prompt_caching_config();
    if not pc_config.get("enabled", True) {
        return False;
    }
    name = model_name.lower();
    return name.startswith("anthropic/") or name.startswith("claude-");
}

def _mark_message_for_caching(msg: dict[str, any]) {
    content = msg.get("content");
    if isinstance(content, str) {
        msg["cache_control"] = _CACHE_CONTROL_EPHEMERAL;
    } elif isinstance(content, list) and len(content) > 0 {
        content[-1]["cache_control"] = _CACHE_CONTROL_EPHEMERAL;
    }
}

def _usage_int(usage: any, key: str) -> int {
    if usage is None {
        return 0;
    }
    val = usage.get(key) if isinstance(usage, dict) else getattr(usage, key, None);
    if val is None {
        detail_key = (
            "cached_tokens"
                if key == "cache_read_input_tokens"
                else "cache_creation_tokens"
                    if key == "cache_creation_input_tokens"
                    else None
        );
        if detail_key {
            ptd = (
                usage.get("prompt_tokens_details")
                    if isinstance(usage, dict)
                    else usage?.prompt_tokens_details
            );
            if ptd is not None {
                val = (
                    ptd.get(detail_key)
                        if isinstance(ptd, dict)
                        else getattr(ptd, detail_key, None)
                );
            }
        }
    }
    try {
        return int(val or 0);
    } except Exception {
        return 0;
    }
}

def _apply_prompt_caching(messages: list[object], tools: list[dict[str, any]] | None) {
    last_sys_idx = -1;
    last_nonsys_idx = -1;
    for (i, msg) in enumerate(messages) {
        if isinstance(msg, dict) {
            if msg.get("role") == "system" {
                last_sys_idx = i;
            } else {
                last_nonsys_idx = i;
            }
        }
    }
    if last_sys_idx >= 0 {
        _sys_msg = messages[last_sys_idx];
        if isinstance(_sys_msg, dict) {
            _mark_message_for_caching(_sys_msg);
        }
    }
    if last_nonsys_idx >= 0 {
        _nonsys_msg = messages[last_nonsys_idx];
        if isinstance(_nonsys_msg, dict) {
            _mark_message_for_caching(_nonsys_msg);
        }
    }
    if tools {
        tools[-1]["cache_control"] = _CACHE_CONTROL_EPHEMERAL;
    }
}

def _quiet_lookup(lookup: Callable, fallback: any) -> any {
    try {
        return lookup();
    } except Exception {
        return fallback;
    }
}

def _litellm_ctx_window(model_name: str) -> int {
    def lookup -> int {
        info = dict(litellm.get_model_info(model_name));
        return int(info.get("max_input_tokens") or info.get("max_tokens") or 0);
    }
    window: int = _quiet_lookup(lookup, 0);
    return window;
}

def _existing_cost(usage_obj: object) -> object {
    return (usage_obj.get("cost") if isinstance(usage_obj, dict) else usage_obj?.cost);
}

def _attach_call_cost(
    usage_obj: object, model_name: str, response: object = None
) -> None {
    if usage_obj is None
        or not (
            _usage_int(usage_obj, "prompt_tokens")
            or _usage_int(usage_obj, "completion_tokens")
            or _usage_int(usage_obj, "total_tokens")
        ) {
        return;
    }
    if _existing_cost(usage_obj) is not None {
        return;
    }
    def lookup -> object {
        return litellm.completion_cost(
            completion_response=(
                response
                    if response is not None
                    else {"model": model_name, "usage": usage_obj}
            ),
            model=model_name
        );
    }
    cost = _quiet_lookup(lookup, None);
    if cost is None {
        return;
    }
    if isinstance(usage_obj, dict) {
        usage_obj["cost"] = cost;
    } else {
        try {
            setattr(usage_obj, "cost", cost);
        } except Exception {}
    }
}

def _usage_to_dict(usage_obj: object) -> dict[str, any] {
    if usage_obj is None {
        return {};
    }
    if isinstance(usage_obj, dict) {
        return dict(usage_obj);
    }
    try {
        dump = usage_obj?.model_dump;
        result = dump() if callable(dump) else dict(vars(usage_obj));
        return result if isinstance(result, dict) else {};
    } except Exception as e {
        logger.debug(f"usage serialization failed, recording an empty payload: {e}");
        return {};
    }
}

def _record_usage(
    mt_run: MTRuntime,
    usage_obj: object,
    model_name: str,
    call_kind: str | None = None,
    finish_reason: str | None = None
) {
    record = _usage_to_dict(usage_obj);
    record["model"] = model_name;
    record["call_kind"] = call_kind or mt_run._call_kind;
    if finish_reason {
        record["finish_reason"] = finish_reason;
    }
    record["cache_read_input_tokens"] = _usage_int(
        usage_obj, "cache_read_input_tokens"
    );
    record["cache_creation_input_tokens"] = _usage_int(
        usage_obj, "cache_creation_input_tokens"
    );
    mt_run._usage_history.append(record);
}

def _usage_step_events(
    mt_run: MTRuntime, usage_base: int
) -> Generator[StreamEvent, None, None] {
    if len(mt_run._usage_history) > usage_base {
        yield StreamEvent(
            event_type="usage_step",
            data=_aggregate_usage(mt_run._usage_history[usage_base:])
        );
    }
}

def _usage_history_total_cost(mt_run: MTRuntime) -> float {
    return sum(
        float(record.get("cost", 0.0) or 0.0) for record in mt_run._usage_history
    );
}
