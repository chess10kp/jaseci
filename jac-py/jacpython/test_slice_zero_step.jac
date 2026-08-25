# Oracle regression: zero-step slices must raise ValueError("slice step cannot
# be zero") instead of hanging the VM. CPython (PySlice_AdjustIndices /
# sliceobject.c) raises before any stepping loop runs; slice_indices() in
# objects.jac now does the same for every slicing lane (list/str/bytes/tuple/
# range/slice.indices), not just the call sites that pre-checked.

import from objects { PyObj, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<slice_zero_step>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

test "list slice with zero step raises ValueError instead of hanging" {
    ns = vm_exec(
        "l = [1, 2, 3, 4, 5, 6]\n"
        "try:\n"
        "    l[5:1:0]\n"
        "except ValueError as e:\n"
        "    msg = str(e)\n"
        "else:\n"
        "    msg = 'no error'\n"
    );
    assert vm_str(ns, "msg") == "slice step cannot be zero";
}

test "zero-step slice.indices matches CPython message" {
    ns = vm_exec(
        "try:\n"
        "    slice(5, 1, 0).indices(6)\n"
        "except ValueError as e:\n"
        "    msg = str(e)\n"
        "else:\n"
        "    msg = 'no error'\n"
    );
    assert vm_str(ns, "msg") == "slice step cannot be zero";
}
