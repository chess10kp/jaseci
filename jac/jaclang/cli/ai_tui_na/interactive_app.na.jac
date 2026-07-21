# InteractiveApp — agent-aware tick: keys → reduce → drain → effects → paint.

import from .libc_tty { tty_poll, tty_wake_ready, tty_drain_wake, tty_clear_wake_fd }
import from .tui { Tui }
import from .keys { parse_key, Key }
import from .input_types {
    UiAction,
    UiActionKind,
    Effect,
    EffectKind,
    FocusTarget
}
import from .reducer { reduce_input, reduce_session }
import from .embed_session_client { EmbedSessionClient }
import from .embed_runtime { EmbedRuntime }
import from .transport { EmbedPyTransport, CmdQueue }
import from .state { EventKind, TuiState, TuiStatus }
import from .session_dispatch { apply_effects_host }
import from .loading_indicator { loading_footer_active, loading_spinner_frame }

glob _FRAME_DRAIN_CAP: int = 64;

obj LoopResult {
    has cont: bool = True,
        painted: bool = False;
}

obj InteractiveApp {
    has tui: Tui = Tui(),
        session: EmbedSessionClient = EmbedSessionClient(),
        embed: EmbedRuntime = EmbedRuntime(),
        transport: EmbedPyTransport = EmbedPyTransport(),
        cmd_queue: CmdQueue = CmdQueue(),
        poll_profile: bool = False,
        poll_calls: int = 0,
        poll_muts: int = 0,
        poll_snaps: int = 0,
        wake_enabled: bool = False,
        session_ready: bool = True;

    def bind_host(
        embed: EmbedRuntime,
        session: EmbedSessionClient,
        transport: EmbedPyTransport,
        cmd_queue: CmdQueue,
        state: TuiState
    ) {
        self.embed = embed;
        self.session = session;
        self.transport = transport;
        self.cmd_queue = cmd_queue;
        self.tui.bind_state(state);
    }

    def bind_renderer(
        transport: EmbedPyTransport, cmd_queue: CmdQueue, state: TuiState
    ) {
        self.transport = transport;
        self.cmd_queue = cmd_queue;
        self.tui.bind_state(state);
    }

    def _session_live -> bool {
        return self.session.started;
    }

    def _turn_in_flight(state: TuiState) -> bool {
        return (
            state.status == TuiStatus.RUNNING
            or state.status == TuiStatus.STOPPING
        );
    }

    def _refresh_session_ready(state: TuiState) {
        if not self.wake_enabled {
            self.session_ready = True;
            return;
        }
        if tty_wake_ready() {
            tty_drain_wake();
            self.session_ready = True;
            return;
        }
        # An empty drain while the agent is still running means more mutations are
        # in flight (stub/real turn). Keep polling until the turn settles.
        if self._turn_in_flight(state) {
            self.session_ready = True;
        }
    }

    def run -> int {
        while self.step(50).cont { }
        return 0;
    }

    def _execute_effects(effects: list[Effect]) {
        apply_effects_host(self.session, self.tui.state, self.cmd_queue, effects);
        for e in effects {
            if (
                e.kind == EffectKind.SEND_PROMPT
                or e.kind == EffectKind.STOP
                or e.kind == EffectKind.RESET
                or e.kind == EffectKind.APPLY_SETTINGS
            ) {
                # submit() may enqueue mutations after the pre-key wake check; arm
                # drain for this frame and any in-flight turn that follows.
                self.session_ready = True;
            }
            if e.kind == EffectKind.REQUEST_RENDER {
                self.tui.request_render(False);
            }
        }
    }

    def inject_key(k: Key) -> bool {
        action = UiAction(kind=UiActionKind.KEY, key=k);
        res = reduce_input(self.tui.state, action);
        self._execute_effects(res.effects);
        if res.quit {
            self.tui.state.quit_flag = True;
        }
        return res.quit;
    }

    def set_focus(target: FocusTarget) {
        action = UiAction(kind=UiActionKind.SET_FOCUS, focus=target);
        reduce_input(self.tui.state, action);
    }

    def _process_keys {
        if not self.transport.key_ready() {
            return;
        }
        raw_key = self.transport.read_key();
        if not raw_key {
            return;
        }
        self.inject_key(parse_key(raw_key));
    }

    def _drain_session -> bool {
        state = self.tui.state;
        if not self._session_live() {
            self.tui.sync_size();
            return True;
        }
        # Event-gated: cross into embedded Python only when the wake pipe (or the
        # always-on fallback) says the session queue has data. Idle frames skip
        # the GIL-heavy poll entirely.
        if self.session_ready {
            if self.poll_profile {
                self.poll_calls += 1;
            }
            if not self.session.drain_into(state, _FRAME_DRAIN_CAP) {
                if self.session.backend_dead {
                    state.upsert_event(
                        -101, EventKind.ERROR, "agent backend stopped responding", "host"
                    );
                    state.dirty = True;
                    self.transport.mark_backend_dead();
                    return False;
                }
                return False;
            }
            if self.wake_enabled {
                # A full/non-empty drain may leave a backlog (queue > drain cap):
                # stay ready so the next frame drains it. Also keep polling while a
                # turn is in flight — the queue can be momentarily empty between
                # the accept receipt and the assistant reply mutations.
                self.session_ready = (
                    self.session.last_batch_count > 0
                    or self._turn_in_flight(state)
                );
            }
        }
        self.tui.sync_size();
        if self.transport.stdin_eof() {
            return False;
        }
        if self.transport.backend_dead() {
            state.upsert_event(
                -101, EventKind.ERROR, "agent backend stopped responding", "host"
            );
            state.dirty = True;
            return False;
        }
        reduce_session(state, state.dirty);
        return True;
    }

    def step(timeout_ms: int) -> LoopResult {
        self.embed.run_without_gil();
        if self._turn_in_flight(self.tui.state) and loading_footer_active(self.tui.state) {
            state = self.tui.state;
            prev = loading_spinner_frame(state.loading_tick);
            state.loading_tick += 1;
            if loading_spinner_frame(state.loading_tick) != prev {
                state.dirty = True;
            }
        }
        # When a backlog is pending (session_ready) don't block: drain at full
        # speed. When idle, block up to timeout_ms so keyboard/wake events return
        # immediately while resize is still noticed within the timeout window.
        poll_timeout: int = timeout_ms;
        if self.wake_enabled and self.session_ready {
            poll_timeout = 0;
        }
        tty_poll(poll_timeout);
        self._refresh_session_ready(self.tui.state);
        self._process_keys();
        self._refresh_session_ready(self.tui.state);
        if not self._drain_session() {
            self.tui.state.quit_flag = True;
            painted = self.tui.paint_once();
            return LoopResult(cont=False, painted=painted);
        }
        painted = self.tui.paint_once();
        return LoopResult(cont=not self.tui.state.quit_flag, painted=painted);
    }

    def shutdown {
        # Detach the wake fd before Python closes the pipe during dispose.
        tty_clear_wake_fd();
        self.tui.stop();
    }
}
