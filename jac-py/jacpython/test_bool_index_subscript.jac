# Bool-as-index subscript oracle (PR#6973 A.4).
#
# bool is an int subclass in CPython, so sequence subscripts coerce it through
# __index__: "abc"[True] == 'b', b"xyz"[False] == 120, (10, 20)[True] == 20.
# PyStr/PyBytes/PyTuple mp_subscript route the index through to_index(), and
# PyBool.to_index() unwraps to PyInt(1)/PyInt(0). Non-integer indices (float)
# must still raise TypeError -- coercion is bool-only, not numeric.

import from objects { PyObj, PyStr, PyError, PyException, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

# Eval `src` (eval-mode) on ceval; returns the raw outcome -- an is_error PyObj
# when the snippet raised, so callers can pin the error channel verbatim.
def vm_eval_raw(src: str) -> PyObj {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    return exec_code(
        unmarshal(host_compile_marshal(src, "<bool_index>", "eval")), [], ns
    );
}

def vm_eval(src: str) -> PyObj {
    outcome = vm_eval_raw(src);
    assert not is_error(outcome);
    return outcome;
}

def err_type(outcome: PyObj) -> str {
    assert isinstance(outcome, PyError);
    return ((outcome as PyError).exception as PyException).type_name;
}

test "str subscripts coerce bool indices" {
    assert to_host(vm_eval('"abc"[True]')) == "b";
    assert to_host(vm_eval('"abc"[False]')) == "a";
}

test "bytes subscripts coerce bool indices" {
    assert to_host(vm_eval('b"xyz"[True]')) == 121;
    assert to_host(vm_eval('b"xyz"[False]')) == 120;
}

test "tuple subscripts coerce bool indices" {
    assert to_host(vm_eval("(10, 20, 30)[True]")) == 20;
    assert to_host(vm_eval("(10, 20, 30)[False]")) == 10;
}

test "bool coercion respects bounds and sign" {
    # True -> 1 indexes the last element of a length-2 tuple; False -> 0.
    assert to_host(vm_eval("(7, 9)[True]")) == 9;
    assert to_host(vm_eval("(7, 9)[False]")) == 7;
}

test "non-integer index still raises TypeError" {
    # Coercion is __index__-gated: float is not an integer index.
    outcome = vm_eval_raw("'abc'[1.0]");
    assert is_error(outcome);
    assert err_type(outcome) == "TypeError";
}
