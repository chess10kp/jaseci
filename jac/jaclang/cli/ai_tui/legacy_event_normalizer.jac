import from jaclang.cli.ai_tui.session_models { UiMutation }
import from jaclang.cli.ai_tui.bridge_schema {
    LIFE_IDLE,
    LIFE_RUNNING,
    LIFE_STOPPING,
    MUT_DIAGNOSTIC,
    MUT_MESSAGE_END,
    MUT_MESSAGE_START,
    MUT_MESSAGE_UPDATE,
    MUT_STATUS,
    MUT_TOOL_END,
    MUT_TOOL_START,
    MUT_TOOL_UPDATE
}


def normalize_status(raw: str) -> str {
    s = raw.strip().lower();
    if s == "idle" {
        return LIFE_IDLE;
    }
    if s == "running" {
        return LIFE_RUNNING;
    }
    if s == "stopping" {
        return LIFE_STOPPING;
    }
    if s in (
        LIFE_IDLE,
        LIFE_RUNNING,
        LIFE_STOPPING,
        "starting",
        "quiescing",
        "disposed",
        "failed"
    ) {
        return s;
    }
    raise ValueError(f"unknown lifecycle status: {raw!r}");
}


def normalize_event_kind(kind: str) -> str {
    k = kind.strip().lower();
    mapping: dict[str, str] = {
        "user": MUT_MESSAGE_START,
        "answer": MUT_MESSAGE_UPDATE,
        "reasoning": MUT_MESSAGE_UPDATE,
        "system": MUT_DIAGNOSTIC,
        "logo": MUT_DIAGNOSTIC,
        "error": MUT_DIAGNOSTIC,
        "phase": MUT_STATUS,
        "status": MUT_STATUS,
        "call": MUT_TOOL_START,
        "tool": MUT_TOOL_START,
        "tool_result": MUT_TOOL_END,
        "img": MUT_MESSAGE_UPDATE
    };
    if k not in mapping {
        raise ValueError(f"unknown legacy event kind: {kind!r}");
    }
    return mapping[k];
}


def legacy_frame_to_mutations(
    frame: dict[str, any], epoch: int = 0, seq_start: int = 1
) -> list[UiMutation] {
    out: list[UiMutation] = [];
    _ = seq_start;

    if "status" in frame {
        life = normalize_status(str(frame.get("status", "")));
        out.append(UiMutation(kind=MUT_STATUS, seq=0, epoch=epoch, lifecycle=life));
    }

    events = frame.get("events");
    if isinstance(events, list) {
        for ev in events {
            if isinstance(ev, dict) {
                _emit_ev(out, ev, epoch, True);
            }
        }
    }

    ev = frame.get("ev");
    if isinstance(ev, dict) {
        _emit_ev(out, ev, epoch, True);
    }

    eva = frame.get("eva");
    if isinstance(eva, dict) {
        _emit_ev(out, eva, epoch, False);
    }

    return out;
}


def _emit_ev(out: list[UiMutation], ev: dict[str, any], epoch: int, full: bool) {
    try {
        m = _legacy_ev(ev, epoch, full);
    } except ValueError {
        return;
    }
    out.append(m);
}


def _legacy_ev(ev: dict[str, any], epoch: int, full: bool) -> UiMutation {
    kind_raw = str(ev.get("kind", ""));
    mut_kind = normalize_event_kind(kind_raw);
    text = str(ev.get("text", ""));
    if kind_raw == "status" {
        life = "";
        raw_life = str(ev.get("status", ""));
        if raw_life {
            try {
                life = normalize_status(raw_life);
            } except ValueError {
                life = "";
            }
        }
        return UiMutation(kind=MUT_STATUS, seq=0, epoch=epoch, lifecycle=life);
    }
    ev_id = str(ev.get("id", ""));
    op = "replace_partial" if full else "text_append";
    if kind_raw in ("answer", "reasoning") and not full {
        op = "thinking_append" if kind_raw == "reasoning" else "text_append";
    }
    if mut_kind == MUT_MESSAGE_START and kind_raw == "user" {
        return UiMutation(
            kind=MUT_MESSAGE_START,
            seq=0,
            epoch=epoch,
            message_id=ev_id,
            part_id=ev_id + ":text",
            op="user",
            text=text,
            payload={"role": "user", "node": str(ev.get("node", ""))}
        );
    }
    if mut_kind == MUT_TOOL_START {
        return UiMutation(
            kind=MUT_TOOL_START,
            seq=0,
            epoch=epoch,
            message_id=ev_id,
            text=text,
            payload={"node": str(ev.get("node", "")), "legacy_kind": kind_raw}
        );
    }
    if mut_kind == MUT_TOOL_END {
        return UiMutation(
            kind=MUT_TOOL_END,
            seq=0,
            epoch=epoch,
            message_id=ev_id,
            text=text,
            payload={"node": str(ev.get("node", ""))}
        );
    }
    return UiMutation(
        kind=mut_kind,
        seq=0,
        epoch=epoch,
        message_id=ev_id,
        part_id=ev_id + ":text",
        op=op,
        text=text,
        diagnostic=text if mut_kind == MUT_DIAGNOSTIC else "",
        payload={"legacy_kind": kind_raw, "node": str(ev.get("node", ""))}
    );
}
