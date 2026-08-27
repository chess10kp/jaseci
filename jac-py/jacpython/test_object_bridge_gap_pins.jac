# Census-0824 object-bridge gap pins.
#
# Pins for two census fingerprints whose root cause sits on the object bridge
# (ops/gapq-bridge.sh lanes: objects). Both root causes were fixed upstream
# after the farm build that produced census-0824, so these pins lock the fixed
# behavior against regression -- CI runs them; they are NOT run locally
# (compute-gated box).
#
# Fingerprint 1 (26 suites): RUN<"SystemError: unsupported opcode 36">
#   Opcode 36 is CPython 3.14's SETUP_ANNOTATIONS, emitted only when
#   `from __future__ import annotations` is active and a scope uses
#   annotations (codegen.c codegen_body). The dispatch arm now binds an empty
#   `__annotations__` dict in the frame locals when absent, never clobbering
#   an existing binding (generated_cases.c.h TARGET(SETUP_ANNOTATIONS):
#   PyMapping_GetOptionalItem -> PyDict_New -> SetItem).
#
# Fingerprint 2 (1 suite, test_minidom):
#   RUN<"TypeError: cannot use 'property_ctor' as a set element
#        (unhashable type: 'property_ctor')">"
#   CPython builtin descriptors are hashable by identity; codec registries,
#   ABC caches, and copy dispatch tables key sets/dicts on them. The
#   property constructor and property instances now answer an identity
#   tp_hashkey ("obj:<id>") instead of inheriting the base unhashable marker.
#
# Fingerprint 3 (conv_funcattrs): RUN<"TypeError: cannot use 'bound_method'
#   as a dict key (unhashable type: 'bound_method')">"
#   CPython hashes bound methods by identity; PyBoundMethod now answers an
#   identity tp_hashkey like PyFunction.
#
# All expectations captured byte-exact from the host oracle (CPython 3.14).

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<obj_bridge_gaps>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

# Run `src`, capturing `expr`'s value or its exception as "Type: message".
def outcome_str(src: str, expr: str) -> str {
    ns = vm_exec(
        src +
        "try:\n"
        "    r = " + expr + "\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    );
    v = to_host(ns["r"]);
    if isinstance(v, str) {
        return v;
    }
    return str(v);
}

# ---------------- SETUP_ANNOTATIONS (opcode 36) ----------------

test "setup_annotations: module scope binds lazy __annotations__ dict" {
    # Host oracle (3.14, future annotations): __annotations__ exists, carries
    # the PEP 563 string form, and is a plain dict.
    src =
        "from __future__ import annotations\n"
        "x: int = 5\n";
    assert outcome_str(src, "('ann', sorted(__annotations__), __annotations__['x'])")
        == "('ann', ['x'], 'int')";
    assert outcome_str(src, "type(__annotations__).__name__") == "dict";
}

test "setup_annotations: class body binds into the class namespace" {
    # Host oracle (3.14): '__annotations__' in D.__dict__ is True, the stored
    # annotation value is the lazy string 'int', and D.__annotations__ IS the
    # dict in the class namespace.
    src =
        "from __future__ import annotations\n"
        "class D:\n"
        "    y: int = 3\n"
        "    z: str\n";
    assert outcome_str(src, "'__annotations__' in D.__dict__") == "True";
    assert outcome_str(src, "D.__dict__['__annotations__']['y']") == "int";
    assert outcome_str(src, "getattr(D, '__annotations__') is D.__dict__['__annotations__']")
        == "True";
}

test "setup_annotations: pre-existing __annotations__ is kept, not clobbered" {
    # CPython's arm only creates the dict when absent; a user-assigned mapping
    # stays the live target for subsequent annotation stores.
    # Host oracle (3.14): (True, ['pre', 'q']).
    src =
        "from __future__ import annotations\n"
        "seed = {'pre': int}\n"
        "__annotations__ = seed\n"
        "q: float = 1.0\n";
    assert outcome_str(src, "(__annotations__ is seed, sorted(seed))")
        == "(True, ['pre', 'q'])";
}

# ---------------- descriptor identity hash ----------------

test "property ctor is a legal set element and dict key" {
    # Host oracle (3.14): {property} works; (True, 1).
    assert outcome_str("s = {property}\n", "(property in s, len(s))") == "(True, 1)";
}

test "property instances hash distinctly from the ctor" {
    # Host oracle (3.14): each property object keys independently by identity,
    # so a fresh instance never collides with the constructor's bucket.
    src = "p = property(lambda self: 1)\n";
    assert outcome_str(src, "p in {property}") == "False";
    assert outcome_str(src, "(p in {p}, p in {property})") == "(True, False)";
    assert outcome_str(src, "({property: 'ctor', p: 'inst'})[p]") == "'inst'";
}

test "bound instance method is a legal dict key" {
    # Host oracle (3.14, test_funcattrs FunctionDictsTest.test_func_as_dict_key):
    # d[fi.a] = value round-trips.
    src =
        "class F:\n"
        "    def a(self):\n"
        "        pass\n"
        "fi = F()\n"
        "value = 'Some string'\n"
        "d = {}\n"
        "d[fi.a] = value\n";
    assert outcome_str(src, "d[fi.a]") == "'Some string'";
}

test "bound methods on distinct instances hash distinctly" {
    src =
        "class F:\n"
        "    def a(self):\n"
        "        pass\n"
        "fi = F()\n"
        "fj = F()\n";
    assert outcome_str(src, "fi.a in {fi.a, fj.a}") == "True";
    assert outcome_str(src, "len({fi.a, fj.a})") == "2";
}
