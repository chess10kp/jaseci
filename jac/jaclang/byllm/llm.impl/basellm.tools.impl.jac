def _tool_call_fragments(chunk: object) -> list[dict[str, any]] {
    raw: (list[object] | None) = None;
    try {
        if chunk?.choices and chunk?.choices?[0]?.delta {
            raw = chunk?.choices?[0]?.delta?.tool_calls;
        } elif isinstance(chunk, dict) {
            _choices: any = chunk.get("choices") or [];
            if _choices {
                _tcs = (_choices[0].get("delta") or {}).get("tool_calls");
                raw = _tcs if isinstance(_tcs, list) else None;
            }
        }
    } except Exception {
        return [];
    }
    if not raw {
        return [];
    }
    out: list[dict[str, any]] = [];
    for (pos, tc) in enumerate(raw) {
        try {
            if isinstance(tc, dict) {
                fn: any = tc.get("function") or {};
                idx = tc.get("index");
                out.append(
                    {
                        "index": int(idx) if idx is not None else pos,
                        "id": tc.get("id") or "",
                        "name": (fn.get("name") if isinstance(fn, dict) else "") or "",
                        "fragment": (
                            fn.get("arguments") if isinstance(fn, dict) else ""
                        )
                            or ""
                    }
                );
            } else {
                idx = tc?.index;
                out.append(
                    {
                        "index": int(idx) if idx is not None else pos,
                        "id": tc?.id or "",
                        "name": tc?.function?.name or "",
                        "fragment": tc?.function?.arguments or ""
                    }
                );
            }
        } except Exception {
            continue;
        }
    }
    return out;
}

obj _ToolDeltaCoalescer {
    has out: list[dict[str, any]],
        state: dict[int, dict[str, any]] = {},
        min_chars: int = _TOOL_DELTA_MIN_CHARS,
        min_interval: float = _TOOL_DELTA_MIN_INTERVAL_S,
        max_per_call: int = _TOOL_DELTA_MAX_PER_CALL;

    def observe(frag: dict[str, any]) -> None {
        idx = frag.get("index", 0);
        st = self.state.get(idx);
        if st is None {
            st = {
                "call_id": "",
                "tool": "",
                "buf": "",
                "last": time.time(),
                "sent": 0,
                "announced": False,
                "capped": False
            };
            self.state[idx] = st;
        }
        if frag.get("id") {
            st["call_id"] = str(frag["id"]);
        }
        if frag.get("name") {
            st["tool"] = str(frag["name"]);
        }
        st["buf"] += str(frag.get("fragment") or "");

        if st["tool"] and not st["announced"] {
            st["announced"] = True;
            self._publish(idx, st);
            return;
        }
        if st["sent"] >= self.max_per_call {
            if not st["capped"] {
                st["capped"] = True;
                self.out.append(
                    {
                        "call_id": st["call_id"],
                        "tool": st["tool"],
                        "arg_fragment": "",
                        "index": idx,
                        "truncated": True
                    }
                );
            }
            return;
        }
        last_val = st["last"];
        last_at = last_val if isinstance(last_val, float) else 0.0;
        if len(str(st["buf"])) >= self.min_chars
            or (time.time() - last_at) >= self.min_interval {
            self._publish(idx, st);
        }
    }

    def _publish(idx: int, st: dict[str, any]) -> None {
        if not st["buf"] and st["sent"] > 0 {
            return;
        }
        self.out.append(
            {
                "call_id": st["call_id"],
                "tool": st["tool"],
                "arg_fragment": st["buf"],
                "index": idx
            }
        );
        st["buf"] = "";
        st["last"] = time.time();
        st["sent"] = st["sent"] + 1;
    }

    def flush {
        for idx in list(self.state.keys()) {
            st = self.state[idx];
            if st["buf"] and st["sent"] < self.max_per_call {
                self._publish(idx, st);
            }
        }
    }
}

def _tool_stream_settings(mt_run: MTRuntime) -> dict[str, any] {
    settings = dict(get_byllm_config().get_tool_stream_config());
    per_call = mt_run.call_params.get("stream_tool_args");
    if per_call is True or per_call is False {
        settings["enabled"] = per_call;
    }
    return settings;
}

def _should_parallelize(mt_run: MTRuntime) -> bool {
    per_call = mt_run.call_params.get("parallelize");
    if per_call is True {
        return True;
    }
    if per_call is False {
        return False;
    }

    return get_byllm_config().get_parallel_config().get("enabled", False);
}

def _rebuild_stream_chunks(chunks: list[any], logging_obj: object) -> dict[str, any] {
    rebuilt: any = (
        litellm.stream_chunk_builder(chunks, logging_obj=logging_obj)
            if _STREAM_CHUNK_BUILDER_ACCEPTS_LOGGING_OBJ
            else litellm.stream_chunk_builder(chunks)
    );
    return rebuilt;
}

def _error_tool_call(call_id: str, tool_name: str, reason: str) -> ToolCall {
    name = tool_name or "unknown_tool";
    def _report_error -> str {
        return (
            f"Tool error: {reason}. "
            f"Re-send the {name} call with corrected arguments."
        );
    }
    _report_error.__name__ = name;

    setattr(_report_error, "_is_error_tool", True);
    return ToolCall(call_id=call_id, tool=Tool(func=_report_error), args={});
}

def _parse_tool_calls(
    mt_run: MTRuntime,
    tool_calls_list: list[any],
    truncated_ids: set | None = None,
    damaged_ids: set | None = None
) -> list[ToolCall] {
    parsed: list[ToolCall] = [];
    for tool_call in tool_calls_list {
        fn = response_field(tool_call, "function");
        call_id = str(response_field(tool_call, "id") or "");
        tool_name = str(response_field(fn, "name") or "") if fn else "";
        tool = mt_run.get_tool(tool_name);
        if tool is None {
            parsed.append(
                _error_tool_call(call_id, tool_name, f"unknown tool '{tool_name}'")
            );
            continue;
        }
        if truncated_ids and call_id in truncated_ids {
            parsed.append(
                _error_tool_call(
                    call_id,
                    tool_name,
                    "the response hit the max_tokens limit before this tool call "
                    "finished, so its arguments were truncated and discarded. Retry "
                    "with a smaller payload (if one argument is very large, split the "
                    "work across multiple calls)"
                )
            );
            continue;
        }
        if damaged_ids and call_id in damaged_ids {
            parsed.append(
                _error_tool_call(
                    call_id,
                    tool_name,
                    "this tool call's arguments arrived malformed and could not be "
                    "parsed, so they were discarded. The arguments you chose were "
                    "not the problem and the payload was not too large: send the "
                    "same call again unchanged"
                )
            );
            continue;
        }
        try {
            raw_args = response_field(fn, "arguments") or "";
            assert isinstance(raw_args, str);
            args_json = json.loads(raw_args) if raw_args else {};
            args = tool.parse_arguments(args_json);
        } except Exception as e {
            parsed.append(
                _error_tool_call(call_id, tool_name, f"invalid tool arguments ({e})")
            );
            continue;
        }
        parsed.append(ToolCall(call_id=call_id, tool=tool, args=args));
    }
    return parsed;
}

def _sanitize_tool_calls(message: dict[str, any]) -> set[str] {
    damaged: set[str] = set();
    tool_calls: any = (message or {}).get("tool_calls") or [];
    for tc in tool_calls {
        fn = response_field(tc, "function");
        if fn is None {
            continue;
        }
        raw = response_field(fn, "arguments");
        valid = False;
        had_args = isinstance(raw, str) and bool(raw.strip());
        if had_args {
            assert isinstance(raw, str);
            try {
                json.loads(raw);
                valid = True;
            } except Exception {
                valid = False;
            }
        }
        if not valid {
            if had_args {
                damaged.add(str(response_field(tc, "id") or ""));
            }
            if isinstance(fn, dict) {
                fn["arguments"] = "{}";
            } else {
                setattr(fn, "arguments", "{}");
            }
        }
    }
    return damaged;
}

def _truncated_call_ids(message: dict[str, any], finish_reason: str) -> set[str] {
    if finish_reason != "length" {
        return set();
    }
    ids: set[str] = set();
    for tc in ((message or {}).get("tool_calls") or []) {
        ids.add(str(response_field(tc, "id") or ""));
    }
    return ids;
}
