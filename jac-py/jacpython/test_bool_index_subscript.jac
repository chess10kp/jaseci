# Bool subscript coercion through to_index() (objects track, PR #6973 A.4).
#
# PyStr.mp_subscript, PyBytes.mp_subscript and PyTuple.mp_subscript route
# their index extraction through PyObj.to_index() (via _seq_index); bool is
# an int subclass, so True indexes as 1 and False as 0 -- exactly CPython's
# behavior ("abc"[True] == 'b'). PyList.mp_ass_subscript and
# PyList.mp_del_subscript share the same helper, so stores and deletes
# coerce bools identically. These pins lock the coerced reads, writes,
# deletes, and the negative arm (float stays TypeError).

import from objects { PyObj, PyStr, PyError, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

# Eval `src` (eval-mode) on ceval; returns the outcome (check with
# is_error) so both the happy path and the raise path are pin-able.
def vm_eval(src: str) -> PyObj {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    return exec_code(
        unmarshal(host_compile_marshal(src, "<bool_index>", "eval")), [], ns
    );
}

test "str subscripts coerce bools to int indices" {
    r = vm_eval("'abc'[True]");
    assert not is_error(r);
    assert (to_host(r) as str) == "b";
    r = vm_eval("'abc'[False]");
    assert not is_error(r);
    assert (to_host(r) as str) == "a";
}

test "bytes subscripts coerce bools to int indices" {
    # b'xyz' is [120, 121, 122]: True -> 1 -> 121, False -> 0 -> 120.
    r = vm_eval("b'xyz'[True]");
    assert not is_error(r);
    assert to_host(r) == 121;
    r = vm_eval("b'xyz'[False]");
    assert not is_error(r);
    assert to_host(r) == 120;
}

test "tuple subscripts coerce bools to int indices" {
    r = vm_eval("(10, 20, 30)[True]");
    assert not is_error(r);
    assert to_host(r) == 20;
    r = vm_eval("(10, 20, 30)[False]");
    assert not is_error(r);
    assert to_host(r) == 10;
}

test "list assignment coerces bools to int indices" {
    # __setitem__ returns None, so `(setitem, l)[1]` yields the mutated list.
    r = vm_eval("(lambda l: (l.__setitem__(True, 'x'), l)[1])(['a', 'b'])[1]");
    assert not is_error(r);
    assert (to_host(r) as str) == "x";
}

test "list deletion coerces bools to int indices" {
    # del l[True] drops index 1; del l[False] drops index 0.
    r = vm_eval("(lambda l: (l.__delitem__(True), len(l))[1])(['a', 'b', 'c'])");
    assert not is_error(r);
    assert to_host(r) == 2;
    r = vm_eval("(lambda l: (l.__delitem__(False), l[0])[1])(['a', 'b', 'c'])");
    assert not is_error(r);
    assert (to_host(r) as str) == "b";
}

test "non-int sequence index stays TypeError" {
    assert is_error(vm_eval("'abc'[1.0]"));
    assert is_error(vm_eval("(10, 20)[None]"));
}
