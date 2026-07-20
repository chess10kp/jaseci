"""AgentSession owns the non-stub provider turn thread (Item 1 recut)."""

import importlib;
import time;
import from threading { Event, Thread }


test "stub session dispose joins workers without timeout" {
    sess_mod = importlib.import_module("jaclang.cli.ai_tui.core.agent_session");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");

    sess = sess_mod.AgentSession(cwd="/tmp/stub-own", stub=True);
    sess.start_feed();
    cmd = models.SessionCommand(
        kind=bridge.CMD_KIND_PROMPT, command_id="stub1", payload={"text": "hello"}
    );
    receipt = sess.submit(cmd);
    assert receipt.accepted == True;
    deadline = time.monotonic() + 2.0;
    while time.monotonic() < deadline {
        if sess.settled {
            break;
        }
        time.sleep(0.02);
    }
    result = sess.dispose(deadline_ms=2000);
    assert result.ok == True;
    assert result.timed_out == False;
}


test "non-stub submit spawns one non-daemon turn thread in workers" {
    sess_mod = importlib.import_module("jaclang.cli.ai_tui.core.agent_session");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    ai_mod = importlib.import_module("jaclang.cli.ai_agent");

    gate = Event();
    started = Event();

    def blocking_run_turn(prompt: str) {
        started.set();
        gate.wait(5.0);
    }

    def always_prepare(prompt: str) -> bool {
        return True;
    }

    old_prepare = getattr(ai_mod, "ui_prepare_turn");
    old_run_turn = getattr(ai_mod, "ui_run_turn");

    setattr(ai_mod, "ui_prepare_turn", always_prepare);
    setattr(ai_mod, "ui_run_turn", blocking_run_turn);

    sess = sess_mod.AgentSession(cwd="/tmp/own-turn", stub=False);
    sess.start_feed();
    cmd = models.SessionCommand(
        kind=bridge.CMD_KIND_PROMPT, command_id="own1", payload={"text": "block me"}
    );
    try {
        receipt = sess.submit(cmd);
        assert receipt.accepted == True;
        assert started.wait(2.0) == True;
        turn_workers = [
            w
            for w in sess._workers
            if w is not sess._worker and isinstance(w, Thread)
        ];
        assert len(turn_workers) == 1;
        assert turn_workers[0].daemon == False;
        gate.set();
        deadline = time.monotonic() + 2.0;
        while time.monotonic() < deadline {
            if not turn_workers[0].is_alive() {
                break;
            }
            time.sleep(0.02);
        }
        assert turn_workers[0].is_alive() == False;
    } finally {
        gate.set();
        setattr(ai_mod, "ui_prepare_turn", old_prepare);
        setattr(ai_mod, "ui_run_turn", old_run_turn);
        sess.dispose(deadline_ms=2000);
    }
}


test "dispose while turn blocked signals stop and joins" {
    sess_mod = importlib.import_module("jaclang.cli.ai_tui.core.agent_session");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    ai_mod = importlib.import_module("jaclang.cli.ai_agent");

    gate = Event();
    started = Event();

    def cancel_aware_run_turn(prompt: str) {
        started.set();
        while not gate.is_set() {
            if sess._stop.is_set() or ai_mod.agent.bus.cancel_requested {
                return;
            }
            time.sleep(0.01);
        }
    }

    old_prepare = getattr(ai_mod, "ui_prepare_turn");
    old_run_turn = getattr(ai_mod, "ui_run_turn");

    def fake_prepare(prompt: str) -> bool {
        ai_mod.agent.bus.set_status("running");
        return True;
    }

    setattr(ai_mod, "ui_prepare_turn", fake_prepare);
    setattr(ai_mod, "ui_run_turn", cancel_aware_run_turn);

    sess = sess_mod.AgentSession(cwd="/tmp/dispose-own", stub=False);
    cmd = models.SessionCommand(
        kind=bridge.CMD_KIND_PROMPT, command_id="own2", payload={"text": "hold"}
    );
    try {
        receipt = sess.submit(cmd);
        assert receipt.accepted == True;
        assert started.wait(2.0) == True;
        result = sess.dispose(deadline_ms=2000);
        assert result.ok == True , result;
        assert result.timed_out == False , result;
    } finally {
        gate.set();
        setattr(ai_mod, "ui_prepare_turn", old_prepare);
        setattr(ai_mod, "ui_run_turn", old_run_turn);
    }
}
