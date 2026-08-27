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
# Fingerprint 6 (object attribute slot wrappers): object.__getattribute__ and
# bound instance.__getattribute__/__setattr__ wrappers hash and compare equal by
# backing receiver + accessor name so inspect/functools set/dict idioms work.
#
# Residual (NOT pinned -- live gap on tip): PyClassMethod / PyStaticMethod /
# their ctors and PyMemberDescr still inherit the base unhashable marker until
# worker2-descriptor-identity-hash and worker2/604-next-objects-gap merge.
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

# ---------------- object attribute slot wrapper hash ----------------

test "unbound object.__getattribute__ is a legal set element" {
    # Host oracle (3.14): object.__getattribute__ in {object.__getattribute__}.
    assert outcome_str(
        "",
        "(object.__getattribute__ in {object.__getattribute__}, len({object.__getattribute__}))"
    ) == "(True, 1)";
}

test "unbound object.__setattr__ works as a dict key" {
    # Host oracle (3.14): {object.__setattr__: 1}[object.__setattr__] -> 1.
    assert outcome_str("", "{object.__setattr__: 1}[object.__setattr__]") == "1";
}

test "bound __getattribute__ wrapper is a legal set element" {
    # Host oracle (3.14): o.__getattribute__ in {o.__getattribute__}; len 1.
    src = "o = object()\n";
    assert outcome_str(
        src,
        "(o.__getattribute__ in {o.__getattribute__}, len({o.__getattribute__}))"
    ) == "(True, 1)";
}

test "bound __getattribute__ and __setattr__ wrappers hash distinctly" {
    # Host oracle (3.14): accessor buckets are disjoint on the same instance.
    src = "o = object()\n";
    assert outcome_str(
        src,
        "(o.__getattribute__ in {o.__setattr__}, o.__setattr__ in {o.__getattribute__})"
    ) == "(False, False)";
}
