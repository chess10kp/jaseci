"""Round-trip regression tests: a typed prompt must yield a *distinct* agent answer.

These guard the exact class of bug where the TUI renders but "input produces no
output" -- or produces output glued onto the user's own row. They drive the
embed-agent bridge surface (`start`/`submit`/`poll`/`snapshot`) that the native
host calls, so a regression in the stub turn, id allocation, or role/op wire
convention fails HERE instead of only in a hand-driven pty.

Root causes guarded:
  1. `_stub_turn` reused the user's message id for the answer, so the native
     reducer appended "echo: X" onto the USER event (one row, never an ANSWER).
  2. The stub omitted `payload={"role": ...}`, so the projector snapshot labeled
     the user message "assistant".
  3. The user MESSAGE_START op must read as "user" for the native reducer.
"""

import importlib;
import time;


def _reset(mod: any) {
    if mod?._adapter is not None {
        mod.dispose(
            '{"schema_id":"jac.ai_tui.bridge.v1","kind":"dispose_spec","reason":"reset","deadline_ms":500}'
        );
    }
}


def _start_stub(mod: any, schema: any) {
    raw = mod.start(
        '{"schema_id":"jac.ai_tui.bridge.v1","kind":"agent_request","stub":true,"model_name":"stub"}'
    );
    start = schema.decode_start_result(raw);
    assert start["ok"] == True;
}


def _drain_until_answer(mod: any, schema: any, tries: int = 60) -> list {
    # The stub answers on a worker thread (~20ms). Poll with retry, accumulating
    # every mutation, until an answer text_append/replace lands or we give up.
    muts: list = [];
    for _ in range(tries) {
        batch = schema.decode_batch(mod.poll("64"));
        for m in batch["mutations"] {
            muts.append(m);
        }
        for m in muts {
            if "echo:" in str(m.get("text", "")) {
                return muts;
            }
        }
        time.sleep(0.03);
    }
    return muts;
}


test "stub prompt yields a DISTINCT answer, not glued onto the user row" {
    mod = importlib.import_module("jaclang.cli.ai_tui.embed_agent");
    schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    _reset(mod);
    _start_stub(mod, schema);

    cmd = schema.encode_command(schema.CMD_KIND_PROMPT, {"text": "roundtrip-hi"});
    receipt = schema.decode_receipt(mod.submit(cmd));
    assert receipt["accepted"] == True;

    muts = _drain_until_answer(mod, schema);

    user_mut = None;
    answer_mut = None;
    for m in muts {
        txt = str(m.get("text", ""));
        if m.get("kind") == schema.MUT_MESSAGE_START and txt == "roundtrip-hi" {
            user_mut = m;
        }
        if "echo: roundtrip-hi" in txt {
            answer_mut = m;
        }
    }

    # The whole point: the agent produced output at all.
    assert answer_mut is not None , "stub produced no answer (input -> no output)";
    assert user_mut is not None , "no user MESSAGE_START mutation was emitted";

    # ...and it is a SEPARATE message from the user's, not appended onto it.
    assert str(user_mut.get("message_id")) != str(answer_mut.get("message_id")) , "answer reused the user's message id -> would glue onto the user row";

    # The user start must read as a user (op convention the native reducer keys on).
    assert str(user_mut.get("op")) == "user";

    _reset(mod);
}


test "stub snapshot labels user and assistant messages with correct roles" {
    mod = importlib.import_module("jaclang.cli.ai_tui.embed_agent");
    schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    _reset(mod);
    _start_stub(mod, schema);

    cmd = schema.encode_command(schema.CMD_KIND_PROMPT, {"text": "role-check"});
    schema.decode_receipt(mod.submit(cmd));
    _drain_until_answer(mod, schema);

    snap = schema.decode_snapshot(mod.snapshot());
    msgs = snap["messages"];

    def _text_of(m: any) -> str {
        return " ".join([str(p.get("text", "")) for p in m.get("parts", [])]);
    }

    user_msgs = [
        m
        for m in msgs
        if str(m.get("role")) == "user"
    ];
    asst_msgs = [
        m
        for m in msgs
        if str(m.get("role")) == "assistant"
    ];

    roles = [str(m.get("role")) for m in msgs];
    assert len(user_msgs) >= 1 , f"no user-role message in snapshot; roles={roles}";
    assert len(asst_msgs) >= 1 , f"no assistant-role message in snapshot; roles={roles}";

    # The user message carries ONLY the prompt -- the answer must not be fused in.
    assert _text_of(user_msgs[0]) == "role-check" , f"user message text not clean: {_text_of(
        user_msgs[0]
    )!r}";
    # The assistant message carries the echoed answer.
    assert "echo: role-check" in _text_of(asst_msgs[0]);

    _reset(mod);
}


test "empty prompt is rejected and produces no answer" {
    mod = importlib.import_module("jaclang.cli.ai_tui.embed_agent");
    schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    _reset(mod);
    _start_stub(mod, schema);

    cmd = schema.encode_command(schema.CMD_KIND_PROMPT, {"text": "   "});
    receipt = schema.decode_receipt(mod.submit(cmd));
    assert receipt["accepted"] == False;

    _reset(mod);
}
