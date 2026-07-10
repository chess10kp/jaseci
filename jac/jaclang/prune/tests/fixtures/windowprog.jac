"""Fixture for statement-window mining.

`build_alpha` and `build_beta` are NOT whole-body clones (their return
statements differ in operand order), but they share a six-statement opening
block (log/total/buf/for-append/len/marker) that normalizes identically. The
window miner must surface that block with both sites, independent of the
surrounding statements. `unrelated` shares no window.
"""

def build_alpha(n: int) -> str {
    log = "start";
    total = 0;
    buf = [];
    for i in range(n) {
        buf.append(i);
    }
    total = len(buf);
    marker = "alpha-done";
    return marker + str(total);
}


def build_beta(m: int) -> str {
    log = "start";
    total = 0;
    buf = [];
    for i in range(m) {
        buf.append(i);
    }
    total = len(buf);
    marker = "beta-done";
    return str(total) + marker;
}


def unrelated(x: int) -> int {
    y = x * 2;
    z = y + 1;
    return z;
}
