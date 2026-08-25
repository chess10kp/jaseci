# Bool subscript coercion through to_index() (objects track, PR #6973 A.4).
#
# PyStr.mp_subscript, PyBytes.mp_subscript and PyTuple.mp_subscript route
# their index extraction through PyObj.to_index(); bool is an int subclass,
# so True indexes as 1 and False as 0 -- exactly CPython's behavior
# ("abc"[True] == 'b'). Routing the shared helper keeps every sequence
# shape on the single bool-coercion path instead of each mp_subscript
# hand-rolling its own index extraction; these pins lock the coerced reads
# for all three sequence shapes.

import from objects { PyObj, PyStr, PyError, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

# Eval `src` (eval-mode) on ceval; fails the test on raise.
def vm_eval(src: str) -> PyObj {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<bool_index>", "eval")), [], ns
    );
    assert not is_error(outcome);
    return outcome;
}

test "str subscripts coerce bools to int indices" {
    assert (to_host(vm_eval("'abc'[True]")) as str) == "b";
    assert (to_host(vm_eval("'abc'[False]")) as str) == "a";
}

test "bytes subscripts coerce bools to int indices" {
    # b'xyz' is [120, 121, 122]: True -> 1 -> 121, False -> 0 -> 120.
    assert to_host(vm_eval("b'xyz'[True]")) == 121;
    assert to_host(vm_eval("b'xyz'[False]")) == 120;
}

test "tuple subscripts coerce bools to int indices" {
    assert to_host(vm_eval("(10, 20, 30)[True]")) == 20;
    assert to_host(vm_eval("(10, 20, 30)[False]")) == 10;
}
