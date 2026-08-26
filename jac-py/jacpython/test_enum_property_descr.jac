# HOST enum.property descriptors on guest instances (gap 784c9220 follow-up).
#
# `from enum import property` lands a REAL host DynamicClassAttribute object in
# a guest class dict -- a PyHostProxy the guest-native descriptor arms
# (PyProperty/PyMemberDescr) never matched, so attribute reads returned the raw
# descriptor instead of routing through its protocol. The fix: descriptor_get
# probes a proxy's type for __get__ and invokes it across the substrate bridge
# (class access keeps the descriptor itself, CPython behavior for
# DynamicClassAttribute), and default_user_getattro honors host DATA descriptors
# over the instance dict.
#
# Idiom: host_compile_marshal -> unmarshal -> exec_code runs each snippet on
# ceval only; results surface through a `result` binding converted via to_host.
import from objects { PyObj, PyStr, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

def vm_result(src: str) -> any {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<enum_prop_descr>", "exec")),
        [],
        ns,
    );
    assert not is_error(outcome);
    return to_host(ns["result"]);
}

test "enum.property: instance read routes through __get__" {
    r = vm_result(
        "from enum import property as eprop\n"
        "class C:\n"
        "    @eprop\n"
        "    def label(self):\n"
        "        return 'L:' + self.tag\n"
        "c = C()\n"
        "c.tag = 'x'\n"
        "result = c.label\n"
    );
    assert r == "L:x";
}

test "enum.property: class access keeps the descriptor itself" {
    # CPython DynamicClassAttribute.__get__(None, owner) answers self, so
    # C.label is the descriptor object -- its type name is 'property'.
    r = vm_result(
        "from enum import property as eprop\n"
        "class C:\n"
        "    @eprop\n"
        "    def label(self):\n"
        "        return 42\n"
        "result = type(C.label).__name__\n"
    );
    assert r == "property";
}

test "enum.property: data descriptor wins over the instance dict" {
    # A host property subclass defines __set__, making it a DATA descriptor:
    # an instance-dict entry of the same name must NOT shadow the getter.
    r = vm_result(
        "from enum import property as eprop\n"
        "class C:\n"
        "    @eprop\n"
        "    def label(self):\n"
        "        return 'getter'\n"
        "c = C()\n"
        "c.label = 'shadow'\n"
        "result = c.label\n"
    );
    assert r == "getter";
}
