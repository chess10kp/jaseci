# Bare type(name, bases, ns) must build guest PyClass objects through type_new,
# not host-routed standins that lose class identity.
import from objects { PyObj, PyStr, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<bare-type>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

test "bare type(name, (), {}) builds a guest class" {
    ns = vm_exec(
        "P = type('P', (), {})\n"
        + "p = P()\n"
        + "same = type(p) is P\n"
        + "sub = isinstance(p, P)\n"
    );
    assert vm_str(ns, "same") == "True", vm_str(ns, "same");
    assert vm_str(ns, "sub") == "True", vm_str(ns, "sub");
}

test "bare type(name, (), {}) rejects non-class bases in-VM" {
    ns = vm_exec(
        "class E:\n"
        + "    def __mro_entries__(self, bases):\n"
        + "        return ()\n"
        + "try:\n"
        + "    type('P', (E(),), {})\n"
        + "    msg = 'NOFAIL'\n"
        + "except TypeError as e:\n"
        + "    msg = str(e)\n"
    );
    assert vm_str(ns, "msg") == "all bases must be classes", vm_str(ns, "msg");
}
