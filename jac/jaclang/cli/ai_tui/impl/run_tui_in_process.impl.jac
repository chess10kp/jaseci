import from jaclang.cli.agent_api { AgentRequest }

impl run_tui_in_process(req: AgentRequest) -> int {
    import os;
    import threading;
    import time;
    import from pathlib { Path }
    import from jaclang.cli.console { console }
    import from jaclang.cli.ai_tui.python_session_bridge {
        PythonSessionBridge,
        argv_stub_flags
    }
    import from jaclang.cli.ai_tui.tui_host { TuiHost, _tui_lib_path }
    import from jaclang.cli.ai_tui.tui_shared {
        _debug_log,
        _embed_byllm_seams,
        _ensure_tui_lib,
        _list_project_files,
        _require_tty,
        _silence_logging_for_tui
    }

    cli_root = Path(str(__file__)).resolve().parent.parent;
    typed_req: AgentRequest = req;
    r: any = typed_req;

    ensured = _ensure_tui_lib(cli_root, force=bool(r?.rebuild_tui));
    if not ensured.ok {
        console.error(str(ensured.error or "failed to build in-process TUI library"));
        if ensured.hint {
            console.error(str(ensured.hint));
        }
        return 1;
    }

    tty_dev = _require_tty();
    if tty_dev is None {
        return 1;
    }

    project = os.path.normpath(str(r?.cwd or os.getcwd()));
    files_env = _list_project_files(project);
    seams = _embed_byllm_seams();
    (prefer_stub, no_stub) = argv_stub_flags();
    debug_log = os.environ.get("JAC_AI_TUI_DEBUG_LOG", "").strip();
    _silence_logging_for_tui(debug_log);

    bridge = PythonSessionBridge();
    start = bridge.start_from_request(
        {
            "cwd": project,
            "stub": prefer_stub,
            "no_stub": no_stub,
            "model_name": str(r?.model or ""),
            "n_ctx": int(r?.n_ctx or 0),
            "project": project,
            "byllm_src": str(seams.get("src", "") or ""),
            "byllm_deps": str(seams.get("deps", "") or ""),
            "debug_log": debug_log
        }
    );
    if not bool(start.get("ok")) {
        console.error(str(start.get("error", "session bridge start failed")));
        return 1;
    }

    presets: list[str] = [];
    presets_raw = start.get("presets", None);
    if presets_raw is not None and isinstance(presets_raw, list) {
        for item in presets_raw {
            name = str(item or "");
            if name {
                presets.append(name);
            }
        }
    }
    presets_env = "\n".join(presets);

    host = TuiHost();
    try {
        host.load(_tui_lib_path(cli_root));
    } except Exception as e {
        _debug_log(f"libtui load failed: {e}");
        bridge.dispose(reason="load_failed", deadline_ms=1000);
        console.error(f"Failed to load in-process TUI library: {e}");
        return 1;
    }

    _log_path = debug_log;
    if _log_path {
        try {
            redirect_fd = os.open(
                _log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644
            );
        } except Exception {
            redirect_fd = os.open(os.devnull, os.O_WRONLY);
        }
    } else {
        redirect_fd = os.open(os.devnull, os.O_WRONLY);
    }
    saved_out = os.dup(1);
    saved_err = os.dup(2);
    os.dup2(redirect_fd, 1);
    os.dup2(redirect_fd, 2);
    os.close(redirect_fd);

    def _restore_fds {
        try {
            os.dup2(saved_out, 1);
            os.close(saved_out);
        } except Exception as e {
            _debug_log(f"restore stdout fd error: {e}");
        }
        try {
            os.dup2(saved_err, 2);
            os.close(saved_err);
        } except Exception as e {
            _debug_log(f"restore stderr fd error: {e}");
        }
    }

    rc = host.start(project, files_env, presets_env, tty_dev);
    if rc != 0 {
        _restore_fds();
        bridge.dispose(reason="init_failed", deadline_ms=1000);
        console.error(f"in-process TUI init failed (tty={tty_dev}, rc={rc})");
        return 1;
    }
    _debug_log(f"in-process TUI init ok tty={tty_dev}");

    stop_evt = threading.Event();
    lock = threading.Lock();
    pending_send_receipts: list[dict[str, any]] = [];

    snap_json = bridge.snapshot_json();
    with lock {
        host.apply_snapshot(snap_json);
        host.render();
    }

    def _feeder {
        try {
            while not stop_evt.is_set() {
                batch_json = bridge.poll_json();
                with lock {
                    if host.apply_batch(batch_json) != 0 {
                        snap = bridge.snapshot_json();
                        host.apply_snapshot(snap);
                    }
                    host.render();
                }
                time.sleep(0.02);
            }
            _debug_log("feeder: stop_evt set");
        } except Exception as e {
            _debug_log(f"feeder error: {e}");
            stop_evt.set();
        }
    }

    def _ticker {
        try {
            while not stop_evt.is_set() {
                n = host.wait_key(50);
                cmds: list[str] = [];
                quit = False;
                with lock {
                    if n > 0 {
                        if host.handle_key() != 0 {
                            quit = True;
                        }
                        while True {
                            cmd = host.next_command();
                            if not cmd {
                                break;
                            }
                            cmds.append(cmd);
                        }
                    }
                    if host.quit_requested() {
                        quit = True;
                    }
                    host.render();
                }
                for cmd in cmds {
                    receipt = bridge.dispatch_legacy_cmd(cmd);
                    send_apply = bridge.apply_send_receipt(receipt);
                    if bool(send_apply.get("apply", False)) {
                        pending_send_receipts.append(send_apply);
                    }
                }
                if pending_send_receipts {
                    with lock {
                        for item in pending_send_receipts {
                            _debug_log(
                                f"send receipt: accepted={item.get('accepted')} " + f"detail={item.get(
                                    'error_detail', ''
                                )!r}"
                            );
                        }
                        pending_send_receipts.clear();
                        host.render();
                    }
                }
                if quit {
                    stop_evt.set();
                }
            }
            _debug_log("ticker: stop_evt set");
        } except Exception as e {
            _debug_log(f"ticker error: {e}");
            stop_evt.set();
        }
    }

    feeder_thread = threading.Thread(target=_feeder, daemon=True);
    ticker_thread = threading.Thread(target=_ticker, daemon=True);
    feeder_thread.start();
    ticker_thread.start();

    try {
        ticker_thread.join();
    } except KeyboardInterrupt {
        stop_evt.set();
    } finally {
        stop_evt.set();
        feeder_thread.join(timeout=2.0);
        bridge.dispose(reason="shutdown", deadline_ms=2000);
        with lock {
            try {
                host.shutdown();
            } except Exception as e {
                _debug_log(f"shutdown error: {e}");
            }
        }
        _restore_fds();
    }

    _debug_log("in-process session exit rc=0");
    return 0;
}
