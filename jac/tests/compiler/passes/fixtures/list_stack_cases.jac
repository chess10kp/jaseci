"""Fixtures for `na_list_stack_ok` stamping in RcFactsPass.

Each function isolates one binding/use shape for a function-local list. The
tracked list local is named `sN` (should stamp) or `nN` (should refuse) so the
test can assert each symbol's mark by name; helper locals carry other names.
"""

def sink_int(v: int) -> int {
    return v;
}

def make_list() -> list[int] {
    return [7, 8];
}

"""Churn shape: literal binding plus allowlisted method calls and len."""
def f_s1_append_churn(n: int) -> int {
    s1 = [1, 2];
    s1.append(3);
    s1.extend([4, 5]);
    t = len(s1);
    return t + n;
}

"""Empty literal bound first, appended later."""
def f_s2_empty_literal() -> int {
    s2 = [];
    s2.append(1);
    return len(s2);
}

"""Iteration and subscript reads/writes stay header-local."""
def f_s3_iter_and_index() -> int {
    s3 = [1, 2, 3];
    s3[0] = 9;
    t = 0;
    for v in s3 {
        t = t + v;
    }
    t = t + s3[1];
    return t;
}

"""Re-binding to another display keeps the slot display-only."""
def f_s4_rebind_literal() -> int {
    s4 = [1];
    s4 = [2, 3];
    return len(s4);
}

"""Bare declaration followed by a display binding."""
def f_s5_decl_then_literal() -> int {
    s5: list[int];
    s5 = [1, 2];
    return len(s5);
}

"""Returned list must keep its heap header."""
def f_n1_return() -> list[int] {
    n1 = [1, 2];
    return n1;
}

"""Aliasing into another local must disqualify the source."""
def f_n2_alias_local() -> int {
    n2 = [1, 2];
    alias2 = n2;
    alias2.append(3);
    return len(n2) + len(alias2);
}

def sink_list(v: list[int]) -> int {
    return len(v);
}

"""Passing the list to a user function is an escape."""
def f_n3_call_arg() -> int {
    n3 = [1, 2];
    return sink_list(n3) + len(n3);
}

"""Re-binding from a call result puts a heap list in the slot."""
def f_n4_rebind_call() -> int {
    n4 = [1, 2];
    n4 = make_list();
    return len(n4);
}

"""Augmented assignment rebuilds through a heap intermediate."""
def f_n5_aug_assign() -> int {
    n5 = [1, 2];
    n5 += [3];
    return len(n5);
}

"""Conditional binding from a non-display value is not display-only."""
def f_n6_conditional_call(c: bool) -> int {
    n6 = [1, 2];
    if c {
        n6 = make_list();
    }
    return len(n6);
}

"""BoolExpr results alias the operand header."""
def f_n7_bool_expr_alias(c: bool) -> int {
    n7 = [1, 2];
    alias7 = n7 or [0];
    return len(alias7);
}

"""Storing into a closure cell captures the header."""
def f_n8_closure_capture() -> int {
    n8 = [1, 2];
    get = lambda () -> int {
        return len(n8);
    };
    return get();
}
