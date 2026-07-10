"""Phase-3b fixture: a pass-through wrapper chain.

Four module-level functions forward through one another with fan-in 1 at each
link and a single-callee body - the exact shape the redundant-layer generator
collapses. No single function looks dead (each is 'used'), so no Tier-1 detector
fires; the relationship is only visible in the call graph.
"""

def real_work(x: int) -> int {
    return x + 1;
}


def dispatch_cmd(x: int) -> int {
    return real_work(x);
}


def run_cmd(x: int) -> int {
    return dispatch_cmd(x);
}


def cli_main(x: int) -> int {
    return run_cmd(x);
}
