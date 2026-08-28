# KeysView-through-standin oracle: guest dict subclass .keys() crossed to the
# host must yield a real dict_keys / collections.abc.KeysView, not AttributeError.

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

::py::
import collections.abc

def _host_keysview_ok(standin: any) -> bool {
    kv = standin.keys();
    return isinstance(kv, collections.abc.KeysView);
}

def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<standin_keysview>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

test "standin replays keys() to a host KeysView" {
    ns = vm_exec(
        "class D(dict):\n"
        "    pass\n"
        "d = D(a=1, b=2)\n"
    );
    standin = to_host(ns["d"]);
    assert _host_keysview_ok(standin);
}
