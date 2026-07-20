"""SessionEventDispatcher serializes projector + queue mutations (Item 2)."""

import importlib;
import time;
import from threading { Barrier, Event, Thread }


def _start_dispatcher(disp: any) -> tuple[any, any] {
    stop = Event();
    th = Thread(target=disp.run_until, args=(stop, ), daemon=False);
    th.start();
    return (stop, th);
}


def _stop_dispatcher(disp: any, th: any, deadline_s: float = 2.0) {
    disp.close();
    th.join(deadline_s);
    assert th.is_alive() == False , "dispatcher thread did not join";
}


test "dispatcher serializes projector and coalesced wire seq is contiguous" {
    disp_mod = importlib.import_module("jaclang.cli.ai_tui.session_event_dispatcher");
    proj_mod = importlib.import_module("jaclang.cli.ai_tui.ui_event_projector");
    qmod = importlib.import_module("jaclang.cli.ai_tui.event_queue");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");

    projector = proj_mod.UiEventProjector();
    projector.state.epoch = 1;
    queue = qmod.TuiEventQueue(max_records=10_000, max_bytes=10_000_000);
    queue.epoch = 1;
    disp = disp_mod.SessionEventDispatcher(projector=projector, queue=queue);
    (stop, th) = _start_dispatcher(disp);

    chunk = "x";
    n_threads = 4;
    per_thread = 100;
    barrier = Barrier(n_threads);

    def worker {
        barrier.wait();
        i = 0;
        while i < per_thread {
            disp.enqueue(
                models.UiMutation(
                    kind=bridge.MUT_MESSAGE_UPDATE,
                    seq=0,
                    epoch=1,
                    message_id="m1",
                    part_id="m1:text",
                    op="text_append",
                    text=chunk
                )
            );
            i += 1;
        }
    }

    workers: list[any] = [];
    t = 0;
    while t < n_threads {
        tw = Thread(target=worker, daemon=False);
        workers.append(tw);
        tw.start();
        t += 1;
    }
    for tw in workers {
        tw.join(5.0);
    }

    _stop_dispatcher(disp, th);
    batch = queue.drain(10_000);
    assert len(batch.mutations) == 1;
    assert batch.first_seq == 1;
    assert batch.last_seq == 1;
    assert batch.mutations[0].text == chunk * n_threads * per_thread;
    assert queue.drain(64).mutations == [];
}


test "dispatcher snapshot_required on projector ValueError" {
    disp_mod = importlib.import_module("jaclang.cli.ai_tui.session_event_dispatcher");
    proj_mod = importlib.import_module("jaclang.cli.ai_tui.ui_event_projector");
    qmod = importlib.import_module("jaclang.cli.ai_tui.event_queue");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");

    projector = proj_mod.UiEventProjector();
    projector.state.epoch = 1;
    queue = qmod.TuiEventQueue();
    queue.epoch = 1;
    disp = disp_mod.SessionEventDispatcher(projector=projector, queue=queue);
    (stop, th) = _start_dispatcher(disp);

    disp.enqueue(
        models.UiMutation(
            kind=bridge.MUT_AGENT_START, seq=0, epoch=99, lifecycle="running"
        )
    );
    _stop_dispatcher(disp, th);

    assert queue.snapshot_required == True;
    batch = queue.drain(64);
    assert len(batch.mutations) == 1;
    assert batch.mutations[0].kind == bridge.MUT_SNAPSHOT_REQUIRED;
    assert "epoch mismatch" in batch.mutations[0].diagnostic;
}


test "dispatcher close drains in-flight enqueued items" {
    disp_mod = importlib.import_module("jaclang.cli.ai_tui.session_event_dispatcher");
    proj_mod = importlib.import_module("jaclang.cli.ai_tui.ui_event_projector");
    qmod = importlib.import_module("jaclang.cli.ai_tui.event_queue");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");

    projector = proj_mod.UiEventProjector();
    projector.state.epoch = 1;
    queue = qmod.TuiEventQueue(max_records=100, max_bytes=10_000_000);
    queue.epoch = 1;
    disp = disp_mod.SessionEventDispatcher(projector=projector, queue=queue);
    (stop, th) = _start_dispatcher(disp);

    n = 5;
    i = 0;
    while i < n {
        disp.enqueue(
            models.UiMutation(kind=bridge.MUT_DIAGNOSTIC, seq=0, epoch=1, text=f"d{i}")
        );
        i += 1;
    }
    _stop_dispatcher(disp, th);

    batch = queue.drain(64);
    assert len(batch.mutations) == n;
    assert batch.first_seq == 1;
    assert batch.last_seq == n;
    seen: list[int] = [];
    for m in batch.mutations {
        seen.append(m.seq);
    }
    expected: list[int] = [];
    j = 1;
    while j <= n {
        expected.append(j);
        j += 1;
    }
    assert seen == expected;
}
