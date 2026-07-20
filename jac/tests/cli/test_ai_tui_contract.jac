"""End-to-end SEAM contract tests for the real-agent -> native-TUI path.

Every other ai_tui test stubs at a boundary: the roundtrip test drives the
`--stub` agent (which bypasses the legacy normalizer entirely), phase2 feeds the
normalizer hand-built frames, and the native selftest feeds `apply_mutation`
hand-built mutation dicts. A mismatch *between* the pieces -- the real bus emits
a kind the normalizer drops, or the normalizer emits an (kind, op) the native
`apply_mutation` ignores -- passes all of them while the live TUI is broken.
That is how the "type input -> no output" and "answer renders as UNKNOWN" bugs
both shipped green.

These two tests close that gap:

  A. REAL-BUS CONTRACT: drive an actual `AgentEventBus` through a full turn and
     run the emitted frames through the REAL `legacy_frame_to_mutations`. The
     frame shapes are authoritative (not hand-built), so a stray kind that kills
     the feed, or a shape drift, fails here.

  B. NORMALIZER <-> NATIVE-APPLY CONFORMANCE: every (kind, op) the normalizer
     actually emits for that real turn must be handled by the native
     `session_apply.na.jac` reducer, and the wire-constant VALUES must match
     between the Python and native `bridge_schema`. A kind the native side
     ignores (tool events were dropped this way) fails here -- statically, with
     no build.
"""

import importlib;
import threading;
import os;
import json;


def _real_turn_mutations -> tuple {
    # Drive a real AgentEventBus through the exact event shapes one turn emits,
    # then push every published frame through the REAL normalizer. Returns
    # (mutations, agent_mod, norm_mod). If any frame kind escapes the feed guard
    # this raises out of the loop -- which is the feed-death bug, caught here.
    agent_mod = importlib.import_module("jaclang.cli.ai_agent");
    norm = importlib.import_module("jaclang.cli.ai_tui.legacy_event_normalizer");

    bus = agent_mod.AgentEventBus();
    bus._lock = threading.Lock();
    bus.active_feed = True;
    q = bus.subscribe();

    bus.begin_turn();
    bus.emit("user", {"text": "roundtrip-hi"});
    bus.set_status("running");
    bus.emit_stream("reasoning", "let me think");
    bus.emit_call(
        {"node": "plan", "text": "read_file", "tokens_in": 10, "tokens_out": 2}
    );
    bus.emit("tool_result", {"text": "file contents"});
    bus.emit_stream("answer", "hello ");
    bus.emit_stream("answer", "world");
    bus.set_status("idle");

    import from queue { Empty }
    muts: list = [];
    seq = 0;
    while True {
        try {
            frame = q.get_nowait();
        } except Empty {
            break;
        }
        batch = norm.legacy_frame_to_mutations(frame, epoch=0, seq_start=seq);
        for m in batch {
            muts.append(m);
            seq += 1;
        }
    }
    bus.unsubscribe(q);
    return (muts, agent_mod, norm);
}


test "real bus turn survives the normalizer and yields the expected shape" {
    (muts, agent_mod, norm) = _real_turn_mutations();
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");

    # The feed did not die: we got a non-trivial mutation stream out the far end.
    assert len(muts) >= 5 , f"too few mutations survived: {len(muts)}";

    # Tally the stream once: which mutation shapes actually came out the far end.
    user_text = "";
    user_op = "";
    saw_running = False;
    saw_idle = False;
    answer_text = "";
    saw_reasoning = False;
    saw_tool_start = False;
    saw_tool_end = False;
    for m in muts {
        k = m.kind;
        op = str(m.op);
        if k == bridge.MUT_MESSAGE_START and str(m.text) == "roundtrip-hi" {
            user_text = str(m.text);
            user_op = op;
        }
        if k == bridge.MUT_STATUS and str(m.lifecycle) == "running" {
            saw_running = True;
        }
        if k == bridge.MUT_STATUS and str(m.lifecycle) == "idle" {
            saw_idle = True;
        }
        # The bus publishes cumulative `ev` frames -> the normalizer emits
        # message_update op="replace_partial" with the FULL text each time. There
        # is no text_append/eva producer in the live path today.
        if k == bridge.MUT_MESSAGE_UPDATE and op == "replace_partial" {
            pl = m.payload if isinstance(m.payload, dict) else {};
            if str(pl.get("legacy_kind", "")) == "reasoning" {
                saw_reasoning = True;
            } else {
                answer_text = str(m.text);
            }
        }
        if k == bridge.MUT_TOOL_START {
            saw_tool_start = True;
        }
        if k == bridge.MUT_TOOL_END {
            saw_tool_end = True;
        }
    }

    # USER prompt: a message_start that reads as a user, carrying the clean text.
    assert user_text == "roundtrip-hi" , "no user MESSAGE_START for the prompt";
    assert user_op == "user" , f"user op must read 'user', got {user_op!r}";

    # STATUS: the set_status("running")/("idle") events must normalize to
    # lifecycle mutations (the kind that used to raise and kill the feed).
    assert saw_running , "no running status mutation";
    assert saw_idle , "no idle status mutation";

    # ANSWER: cumulative replace_partial -> the final frame carries the full reply.
    assert answer_text == "hello world" , f"answer text wrong: {answer_text!r}";

    # REASONING: also a replace_partial, distinguished by legacy_kind in payload.
    assert saw_reasoning , "no reasoning message_update";

    # TOOL events: a real turn's call/tool_result must reach the wire as tool
    # mutations (they are dropped downstream today -- see the conformance test).
    assert saw_tool_start , "tool call did not normalize to MUT_TOOL_START";
    assert saw_tool_end , "tool_result did not normalize to MUT_TOOL_END";
}


test "every (kind, op) the normalizer emits is handled by native apply_mutation" {
    (muts, agent_mod, norm) = _real_turn_mutations();
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");

    here = os.path.dirname(os.path.abspath(__file__));
    cli_dir = os.path.abspath(os.path.join(here, "..", "..", "jaclang", "cli"));
    na_dir = os.path.join(cli_dir, "ai_tui_na");
    apply_src = open(os.path.join(na_dir, "session_apply.na.jac")).read();
    manifest = json.loads(
        open(os.path.join(cli_dir, "ai_tui", "bridge_schema.manifest.json")).read()
    );
    manifest_wire_values: set = set();
    for section in ("cmd_kinds", "dispositions", "lifecycles", "mutations") {
        body = manifest.get(section, {});
        if isinstance(body, dict) {
            for value in body.values() {
                manifest_wire_values.add(str(value));
            }
        }
    }

    # Build wire-value -> constant-name from the Python bridge, so we can look up
    # what the native side must branch on for each kind we actually emitted.
    val_to_name: dict = {};
    for attr in dir(bridge) {
        if attr.startswith("MUT_") {
            val_to_name[str(getattr(bridge, attr))] = attr;
        }
    }

    kinds = set();
    ops = set();
    for m in muts {
        kinds.add(str(m.kind));
        if m.kind == bridge.MUT_MESSAGE_UPDATE and str(m.op) {
            ops.add(str(m.op));
        }
    }

    unhandled_kinds: list = [];
    drifted_values: list = [];
    for kv in kinds {
        name = val_to_name.get(kv, "");
        assert name , f"emitted kind {kv!r} has no MUT_ constant in the Python bridge";
        # Value parity: manifest is the single source; native schema is generated from it.
        if kv not in manifest_wire_values {
            drifted_values.append(kv);
        }
        # Handled: the native reducer must actually compare against this constant
        # (import presence alone is not proof -- it must be branched on).
        if ("== " + name) not in apply_src {
            unhandled_kinds.append(name);
        }
    }

    assert not drifted_values , f"manifest missing wire values for emitted kinds (drift): {drifted_values}";
    assert not unhandled_kinds , f"native apply_mutation never branches on these kinds the normalizer "
    f"emits (silently dropped in the TUI): {unhandled_kinds}";

    # Append-semantic message ops MUST be recognized explicitly by the native
    # reducer -- an unrecognized "*_append" op falls into the default branch and
    # REPLACES the row instead of appending, silently corrupting a stream. (Replace
    # -semantic ops are correctly the default, so they need no literal.)
    unhandled_ops: list = [];
    for opv in ops {
        if "append" in opv and ('"' + opv + '"') not in apply_src {
            unhandled_ops.append(opv);
        }
    }
    assert not unhandled_ops , f"native apply_mutation does not explicitly handle these append ops "
    f"(they would wrongly REPLACE instead of append): {unhandled_ops}";
}
