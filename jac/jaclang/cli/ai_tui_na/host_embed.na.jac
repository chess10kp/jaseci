import os;
import sys;

import from .libc_tty { tty_open, tty_close, tty_configure_device }
import from .tui_loop { tui_loop_once }
import from .tui_core {
    tui_populate_state,
    tui_enter_screen,
    tui_leave_screen,
    tui_seed_agent_meta
}
import from .runtime { TuiRuntime }
import from .embed_models { AgentRequest }
import from .embed_runtime { EmbedRuntime }
import from .embed_session_client { EmbedSessionClient }
import from .cli_args { parse_argv, print_help, print_error }

# Phase 4: CPython imports live only in embed_runtime.na.jac.
# Phase 5: input goes through reducer; InteractiveApp available for injected-key tests.


def _resolve_project(cli_project: str, cli_cwd: str) -> str {
    if cli_project {
        return cli_project;
    }
    if cli_cwd {
        return cli_cwd;
    }
    cwd = os.getcwd();
    return cwd if cwd is not None else "";
}

def _resolve_cwd(cli_cwd: str) -> str {
    if cli_cwd {
        return cli_cwd;
    }
    cwd = os.getcwd();
    return cwd if cwd is not None else "";
}

def _bind_runtime(rt: TuiRuntime, embed: EmbedRuntime, session: EmbedSessionClient) {
    rt.embed = embed;
    rt.session = session;
}

def _run_embed -> None {
    cli = parse_argv(sys.argv);
    if cli.show_help {
        print_help(os.path.basename(sys.argv[0]));
        return;
    }
    if cli.bad {
        print_error(os.path.basename(sys.argv[0]), cli.bad);
        sys.exit(2);
    }

    if cli.tty {
        tty_configure_device(cli.tty);
    }

    proj_s = _resolve_project(cli.project, cli.cwd);

    embed = EmbedRuntime();
    boot = embed.boot();
    if not boot.ok {
        return;
    }

    bind = embed.bind();
    if not bind.ok {
        embed.force_finalize_unsafe();
        return;
    }

    session = EmbedSessionClient(runtime=embed);
    start = session.start(
        AgentRequest(
            cwd=_resolve_cwd(cli.cwd),
            stub=cli.want_stub(),
            model_name=cli.model,
            n_ctx=cli.n_ctx,
            project=proj_s,
            byllm_src=cli.byllm_src,
            byllm_deps=cli.byllm_deps,
            debug_log=cli.debug_log,
            no_stub=cli.stub_mode == 0
        )
    );
    if not start.ok {
        # start() is a side-effecting transaction. If the managed call executed
        # and then failed (decode error or ok=false), session.start() has already
        # performed bounded dispose and set worker safety from runtime-confirmed
        # quiescence. When the managed call never executed, workers_safe stays
        # False. Either way: do NOT override with an unconditional
        # mark_workers_safe(True) — that finalized over a live _legacy_feed
        # thread (the Phase 4 hang). Gate finalization on quiescence, not start.ok.
        embed.finalize_if_safe();
        return;
    }

    rt = TuiRuntime();
    _bind_runtime(rt, embed, session);
    state = rt.state;
    rt.cmd_queue.clear();
    state.ipc_fd = -1;
    tui_populate_state(state, proj_s, "", "");
    tui_seed_agent_meta(state, start.model_name, start.presets, cli.model);
    session.bootstrap_state(state);
    tty_fd: int = tty_open();
    if tty_fd < 0 {
        disp = session.dispose(reason="tty_open_failed", deadline_ms=1000);
        embed.mark_workers_safe(not disp.timed_out);
        embed.finalize_if_safe();
        return;
    }
    state.render_fd = tty_fd;
    tui_enter_screen(state);

    try {
        while tui_loop_once(rt) { }
    } finally {
        tui_leave_screen(state);
        tty_close();
        disp2 = session.dispose(reason="quit", deadline_ms=2000);
        embed.mark_workers_safe(not disp2.timed_out);
        embed.finalize_if_safe();
    }
}


with entry {
    _run_embed();
}
