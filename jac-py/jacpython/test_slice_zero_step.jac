# Oracle pins for slice_indices' zero-step guard (CPython
# PySlice_AdjustIndices raises "slice step cannot be zero" before any
# stepping loop runs). Without the in-function guard, any caller that skips
# the _zero_step_error pre-check feeds a zero step into an unbounded
# stepping loop and hangs the VM; with it, slice_indices itself fails fast.

import from objects { PySlice, PyInt, py_none, slice_indices }

def _slice_indices_with_step(step: int, length: int) -> list[int] {
    sl = PySlice(t="slice", start=py_none(), stop=py_none(), step=PyInt(t="int", val=step));
    return slice_indices(sl, length);
}

test "slice_indices raises ValueError for zero step instead of hanging" {
    raised = False;
    message = "";
    try {
        _slice_indices_with_step(0, 3);
    } except ValueError as e {
        raised = True;
        message = str(e);
    }
    assert raised , "slice_indices accepted a zero step (would hang steppers)";
    assert message == "slice step cannot be zero" , message;
}

test "slice_indices still resolves nonzero steps" {
    fwd = _slice_indices_with_step(2, 6);
    assert len(fwd) == 3;
    assert fwd[0] == 0 and fwd[1] == 6 and fwd[2] == 2;
}
