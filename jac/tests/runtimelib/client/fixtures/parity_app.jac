"""Minimal backend fixture for the cross-transport parity test.

The SAME app is booted twice -- once through the jac-scale stack
(ScaleTestClient, endpoint profile "test") and once through the desktop
in-process bridge (`inprocess_dispatch`, endpoint profile "desktop") -- and
the normalized envelopes must match field-for-field. One walker, one plain
function, and one generator function (SSE streaming) cover the envelope
shapes every transport must agree on.
"""

walker:pub greet {
    has name: str = "world";

    can run with Root entry {
        report {"greeting": f"hello {self.name}"};
    }
}

def:pub add(a: int, b: int) -> int {
    return a + b;
}

def:pub stream_numbers(n: int) -> Iterator[dict] {
    for i in range(n) {
        yield {"n": i};
    }
}
