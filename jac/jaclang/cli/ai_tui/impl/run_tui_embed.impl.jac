import from jaclang.cli.agent_api { AgentRequest }

impl run_tui_embed(req: AgentRequest) -> int {
    import os;
    import from pathlib { Path }
    import from jaclang.cli.console { console }
    import from jaclang.cli.ai_tui.tui_shared {
        _build_embed_argv,
        _embed_byllm_seams,
        _ensure_embed_host,
        _require_tty
    }

    cli_root = Path(str(__file__)).resolve().parent.parent;

    ensured = _ensure_embed_host(cli_root, force=bool(req?.rebuild_tui));
    if not ensured.ok {
        console.error(str(ensured.error or "failed to build embed TUI host"));
        if ensured.hint {
            console.error(str(ensured.hint));
        }
        return 1;
    }
    host_bin = str(ensured.path);

    if _require_tty() is None {
        return 1;
    }

    r: any = req;

    argv: list[str] = [host_bin];
    seams = _embed_byllm_seams();
    for flag in _build_embed_argv(r, seams) {
        argv.append(flag);
    }
    child = dict(os.environ);

    if os.environ.get("JAC_STANDALONE") == "1" {
        pyhome = os.environ.get("PYTHONHOME", "").strip();
        if pyhome {
            rt = os.path.dirname(pyhome);
            if rt and os.path.isfile(os.path.join(rt, ".ok")) {
                child["JAC_RT_DIR"] = rt;
            }
        }
    }

    try {
        os.execve(host_bin, argv, child);
    } except Exception as e {
        console.error(f"failed to launch embed TUI host {host_bin}: {e}");
        return 1;
    }
    return 0;
}
