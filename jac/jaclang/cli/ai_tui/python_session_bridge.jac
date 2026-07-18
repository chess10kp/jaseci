import os;
import sys;

import from jaclang.cli.ai_tui.bridge_schema {
    CMD_KIND_ABORT,
    CMD_KIND_APPLY_SETTINGS,
    CMD_KIND_PROMPT,
    CMD_KIND_RESET,
    DISP_REJECTED,
    encode_batch,
    encode_snapshot
}
import from jaclang.cli.ai_tui.ipc_schema {
    CMD_SEND,
    CMD_STOP,
    CMD_RESET,
    CMD_QUIT,
    CMD_APPLY,
    RECEIPT_REJECTED_ERROR
}
import from jaclang.cli.ai_tui.session_models {
    CommandError,
    CommandReceipt,
    SessionCommand,
    mutation_dict
}
import from jaclang.cli.ai_tui.tui_session_adapter {
    TuiSessionAdapter,
    make_abort_command,
    make_prompt_command,
    make_reset_command
}
import from jaclang.cli.ai_tui.tui_shared {
    _debug_log,
    _dispatch_cmd,
    _embed_byllm_seams,
    _silence_logging_for_tui
}


obj PythonSessionBridge {
    has adapter: TuiSessionAdapter = TuiSessionAdapter(),
        started: bool = False,
        stub: bool = True,
        _poll_count: int = 0;

    def start_from_request(req: dict[str, any] | None = None) -> dict[str, any] {
        body: dict[str, any] = req if req is not None else {};
        byllm_src = str(body.get("byllm_src", "") or "");
        byllm_deps = str(body.get("byllm_deps", "") or "");
        debug_log = str(body.get("debug_log", "") or "");
        _apply_path_env(byllm_src, byllm_deps);
        _silence_logging_for_tui(debug_log);
        self._poll_count = 0;

        if self.started {
            try {
                self.adapter.dispose(reason="re-start", deadline_ms=1000);
            } except Exception { }
            self.started = False;
        }

        prefer_stub = bool(body.get("stub", False));
        no_stub = bool(body.get("no_stub", False));
        model_name = str(body.get("model_name", "") or "");
        project = str(body.get("project", "") or body.get("cwd", "") or "");
        n_ctx = 0;
        try {
            n_ctx = int(body.get("n_ctx", 0) or 0);
        } except Exception { }

        cwd = str(body.get("cwd", "") or os.getcwd());
        self.adapter = TuiSessionAdapter(
            cwd=cwd, stub=prefer_stub, model_name=model_name or "stub"
        );

        _debug_log(
            f"PythonSessionBridge.start: stub={prefer_stub!r} model={model_name!r} " + f"n_ctx={n_ctx} project={project!r}"
        );

        if prefer_stub {
            return self._finish_start(
                self._start_adapter(stub=True, model_name=model_name or "stub"),
                model_name=model_name or "stub"
            );
        }
        try {
            self._start_real(model_name, n_ctx=n_ctx, project=project);
            (active_model, presets) = _agent_ui_meta(False);
            result = self.adapter.start(
                {"cwd": cwd, "stub": False, "model_name": active_model or "agent"}
            );
            if not result.ok {
                return {
                    "ok": False,
                    "session_id": "",
                    "epoch": 0,
                    "error": result.error or "adapter start failed",
                    "model_name": "",
                    "presets": []
                };
            }
            self.started = True;
            self.stub = False;
            return {
                "ok": True,
                "session_id": result.session_id,
                "epoch": result.epoch,
                "error": "",
                "model_name": active_model,
                "presets": presets
            };
        } except Exception as e {
            _debug_log(f"PythonSessionBridge._start_real failed: {e}");
            if no_stub {
                return {
                    "ok": False,
                    "session_id": "",
                    "epoch": 0,
                    "error": str(e),
                    "model_name": "",
                    "presets": []
                };
            }
            return self._finish_start(
                self._start_adapter(stub=True, model_name="stub", reason=str(e)),
                model_name="stub",
                presets=["stub"]
            );
        }
    }

    def submit_prompt(text: str, command_id: str = "") -> CommandReceipt {
        return self._submit(make_prompt_command(text, command_id));
    }

    def submit_abort(command_id: str = "") -> CommandReceipt {
        return self._submit(make_abort_command(command_id));
    }

    def submit_reset(command_id: str = "") -> CommandReceipt {
        return self._submit(make_reset_command(command_id));
    }

    def poll_json(cap: int = 64) -> str {
        self._poll_count += 1;
        n = cap if cap > 0 else 64;
        batch = self.adapter.poll(n);
        muts: list[any] = [];
        for m in batch.mutations {
            muts.append(mutation_dict(m));
        }
        if self._poll_count <= 5 or self._poll_count % 100 == 0 {
            _debug_log(
                f"PythonSessionBridge.poll #{self._poll_count} " + f"batched={len(
                    muts
                )} epoch={batch.epoch}"
            );
        }
        return encode_batch(batch.epoch, batch.first_seq, batch.last_seq, muts);
    }

    def snapshot_json -> str {
        snap = self.adapter.snapshot();
        model = snap.model_name or self.adapter.model_name;
        if not self.adapter.stub {
            try {
                import from jaclang.cli.ai_agent {
                    agent_model as _am,
                    agent as _agent_rt
                }
                resolved = str(_am.model_name) or str(_agent_rt.bus.model_name);
                if resolved {
                    model = resolved;
                }
            } except Exception { }
        }
        msgs: list[any] = [];
        for m in snap.messages {
            parts: list[any] = [];
            for p in m.parts {
                parts.append(
                    {
                        "id": p.id,
                        "part_type": p.part_type,
                        "text": p.text,
                        "tool_name": p.tool_name,
                        "tool_args": p.tool_args,
                        "image_ref": p.image_ref
                    }
                );
            }
            msgs.append(
                {"id": m.id, "role": m.role, "created_at": m.created_at, "parts": parts}
            );
        }
        return encode_snapshot(
            snap.epoch,
            snap.base_seq,
            snap.lifecycle,
            msgs,
            model_name=model,
            active=snap.active
        );
    }

    def dispose(reason: str = "dispose", deadline_ms: int = 2000) -> dict[str, any] {
        if not self.started {
            return {
                "ok": True,
                "timed_out": False,
                "reason": reason,
                "joined_workers": 0
            };
        }
        result = self.adapter.dispose(reason=reason, deadline_ms=deadline_ms);
        if not self.adapter.stub {
            try {
                import from jaclang.cli.ai_agent { ui_stop }
                ui_stop();
            } except Exception as e {
                _debug_log(f"PythonSessionBridge.dispose: ui_stop failed: {e}");
            }
        }
        self.started = False;
        return {
            "ok": result.ok,
            "timed_out": result.timed_out,
            "reason": result.reason,
            "joined_workers": result.joined_workers
        };
    }

    def dispatch_legacy_cmd(cmd: str) -> dict[str, any] {
        raw = cmd.strip();
        if not raw {
            return _receipt_dict(
                accepted=False,
                disposition=DISP_REJECTED,
                error_code="empty",
                error_message="empty"
            );
        }
        (verb, payload) = _split_legacy_cmd(raw);
        if verb == CMD_SEND {
            receipt = self.submit_prompt(payload);
            out = _receipt_from_obj(receipt);
            out["verb"] = CMD_SEND;
            out["apply_send"] = True;
            out["pending_text"] = payload;
            return out;
        }
        if verb == CMD_STOP {
            return _receipt_from_obj(self.submit_abort());
        }
        if verb == CMD_RESET {
            return _receipt_from_obj(self.submit_reset());
        }
        if verb == CMD_QUIT {
            self.submit_abort();
            return _receipt_dict(accepted=True, disposition="ok");
        }
        if verb == CMD_APPLY {
            return _receipt_from_obj(self._submit_apply_raw(payload));
        }
        return _receipt_dict(
            accepted=False,
            disposition=DISP_REJECTED,
            error_code="unknown",
            error_message=verb
        );
    }

    def apply_send_receipt(receipt: dict[str, any]) -> dict[str, any] {
        if not bool(receipt.get("apply_send", False)) {
            return {"apply": False};
        }
        accepted = bool(receipt.get("accepted", False));
        pending_text = str(receipt.get("pending_text", "") or "");
        if accepted {
            return {
                "apply": True,
                "accepted": True,
                "history_text": pending_text,
                "error_detail": ""
            };
        }
        detail = str(receipt.get("error_code", "") or "");
        if not detail {
            detail = str(receipt.get("error_message", "") or "");
        }
        if not detail {
            detail = RECEIPT_REJECTED_ERROR;
        }
        return {
            "apply": True,
            "accepted": False,
            "history_text": "",
            "error_detail": detail
        };
    }

    def _start_adapter(
        stub: bool, model_name: str = "stub", reason: str = ""
    ) -> dict[str, any] {
        if reason {
            sys.stderr.write(f"jac-ai-tui: using stub agent ({reason})\n");
            sys.stderr.write(
                "  pass --byllm-src=<jac-byllm checkout> and "
                "--byllm-deps=<dep dirs (litellm, openai, ...)> for the real agent.\n"
            );
        }
        result = self.adapter.start(
            {"cwd": os.getcwd(), "stub": stub, "model_name": model_name}
        );
        if not result.ok {
            return {"ok": False, "error": result.error or "adapter start failed"};
        }
        self.started = True;
        self.stub = stub;
        return {
            "ok": True,
            "session_id": result.session_id,
            "epoch": result.epoch,
            "error": ""
        };
    }

    def _start_real(model_name: str, n_ctx: int = 0, project: str = "") {
        import from jaclang.cli.ai_agent { ui_configure }
        _debug_log(
            f"_start_real: ui_configure(model={model_name!r} n_ctx={n_ctx} project={project!r})"
        );
        ui_configure(model_override=model_name, n_ctx=n_ctx, project=project);
    }

    def _finish_start(
        got: dict[str, any], model_name: str = "", presets: list[str] | None = None
    ) -> dict[str, any] {
        preset_list: list[str] = presets if presets is not None else [];
        if not preset_list and bool(got.get("ok")) {
            (_, preset_list) = _agent_ui_meta(True);
        }
        active_model = model_name or "stub";
        if not active_model {
            active_model = "stub";
        }
        return {
            "ok": bool(got.get("ok")),
            "session_id": str(got.get("session_id", "")),
            "epoch": int(got.get("epoch", 0)),
            "error": str(got.get("error", "")),
            "model_name": active_model,
            "presets": preset_list
        };
    }

    def _submit(cmd: SessionCommand) -> CommandReceipt {
        if not self.started {
            return CommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                command_id=cmd.command_id,
                error=CommandError(code="not_started", message="bridge not started")
            );
        }
        return self.adapter.submit(cmd);
    }

    def _submit_apply_raw(raw_args: str) -> CommandReceipt {
        if self.adapter.stub {
            return CommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                error=CommandError(code="stub", message="apply not supported in stub")
            );
        }
        import from threading { Event }
        line = "APPLY:" + raw_args if raw_args else "APPLY";
        try {
            _dispatch_cmd(line, Event(), None);
            return CommandReceipt(accepted=True, disposition="ok");
        } except Exception as e {
            return CommandReceipt(
                accepted=False,
                disposition=DISP_REJECTED,
                error=CommandError(code="apply_failed", message=str(e))
            );
        }
    }
}


def _apply_path_env(byllm_src: str = "", byllm_deps: str = "") {
    if byllm_src and byllm_src not in sys.path {
        sys.path.insert(0, byllm_src);
    }
    for d in byllm_deps.split(os.pathsep) {
        if d and d not in sys.path {
            sys.path.append(d);
        }
    }
}


def _agent_ui_meta(stub: bool) -> tuple[str, list[str]] {
    if stub {
        return ("stub", ["stub"]);
    }
    try {
        import from jaclang.cli.ai_agent { ui_settings }
        settings = ui_settings();
        model = str(settings.get("model", "") or "");
        presets: list[str] = [];
        for raw in settings.get("presets", []) or [] {
            name = str(raw or "");
            if name {
                presets.append(name);
            }
        }
        return (model, presets);
    } except Exception {
        return ("", []);
    }
}


def _split_legacy_cmd(raw: str) -> tuple[str, str] {
    colon = raw.find(":");
    if colon > 0 {
        return (raw[:colon].upper(), raw[colon + 1:]);
    }
    parts = raw.split(" ");
    if parts {
        verb = parts[0].upper();
        payload = " ".join(parts[1:]) if len(parts) > 1 else "";
        return (verb, payload);
    }
    return ("", "");
}


def _receipt_from_obj(receipt: CommandReceipt) -> dict[str, any] {
    err = receipt.error if receipt.error is not None else CommandError();
    return _receipt_dict(
        accepted=receipt.accepted,
        disposition=receipt.disposition,
        command_id=receipt.command_id,
        prompt_id=receipt.prompt_id,
        error_code=err.code,
        error_message=err.message
    );
}


def _receipt_dict(
    accepted: bool,
    disposition: str = DISP_REJECTED,
    command_id: str = "",
    prompt_id: str = "",
    error_code: str = "",
    error_message: str = ""
) -> dict[str, any] {
    return {
        "accepted": accepted,
        "disposition": disposition,
        "command_id": command_id,
        "prompt_id": prompt_id,
        "error_code": error_code,
        "error_message": error_message,
        "apply_send": False,
        "pending_text": ""
    };
}


def argv_stub_flags -> tuple[bool, bool] {
    import sys;

    stub_mode = -1;
    for a in sys.argv {
        if a == "--stub" {
            stub_mode = 1;
        } elif a == "--no-stub" {
            stub_mode = 0;
        }
    }
    prefer_stub = stub_mode == 1;
    no_stub = stub_mode == 0;
    return (prefer_stub, no_stub);
}
