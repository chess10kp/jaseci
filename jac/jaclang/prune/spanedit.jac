import hashlib;


obj SpanEdit {
    has pos_start: int,
        pos_end: int,
        replacement: bytes = b"",
        expected_hash: str = "",
        note: str = "";
}


obj EditResult {
    has data: bytes,
        applied: int,
        ok: bool,
        errors: list[str] = [];
}


def hash_span(data: bytes, start: int, end: int) -> str {
    return hashlib.sha256(data[start:end]).hexdigest()[:16];
}


def make_edit(
    data: bytes, start: int, end: int, replacement: bytes = b"", note: str = ""
) -> SpanEdit {
    return SpanEdit(
        pos_start=start,
        pos_end=end,
        replacement=replacement,
        expected_hash=hash_span(data, start, end),
        note=note
    );
}


def _edit_start(e: SpanEdit) -> int {
    return e.pos_start;
}


def apply_edits(data: bytes, edits: list[SpanEdit]) -> EditResult {
    errors: list[str] = [];
    n = len(data);

    for e in edits {
        if e.pos_start < 0 or e.pos_end > n or e.pos_start > e.pos_end {
            errors.append(
                f"edit out of bounds [{e.pos_start},{e.pos_end}] on {n} bytes ({e.note})"
            );
        } elif e.expected_hash != ""
        and hash_span(data, e.pos_start, e.pos_end) != e.expected_hash {
            errors.append(
                f"pre-text hash mismatch at [{e.pos_start},{e.pos_end}] ({e.note})"
            );
        }
    }
    if errors {
        return EditResult(data=data, applied=0, ok=False, errors=errors);
    }

    ordered = sorted(edits, key=_edit_start);
    prev_end = -1;
    for e in ordered {
        if e.pos_start < prev_end {
            errors.append(f"overlapping edits near byte {e.pos_start} ({e.note})");
        }
        prev_end = max(prev_end, e.pos_end);
    }
    if errors {
        return EditResult(data=data, applied=0, ok=False, errors=errors);
    }

    out = data;
    for e in sorted(edits, key=_edit_start, reverse=True) {
        out = out[:e.pos_start] + e.replacement + out[e.pos_end:];
    }
    return EditResult(data=out, applied=len(edits), ok=True, errors=[]);
}
