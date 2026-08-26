# __kwdefaults__ parity pins -- keyword-only default tables vs host CPython.
#
# Scope (objects-lane): every producer of `__kwdefaults__` on a guest function
#   A. MAKE_FUNCTION kwdefaults table (compiler_emit emit_function_kwdefaults)
#   B. PyFunc attribute protocol (ceval __kwdefaults__ get/set, live-dict
#      semantics, None when no kw-only default exists)
#   C. dataclass-generated __init__ with kw_only fields (@dataclass facade,
#      dc_build_init signature synthesis)
# Every expected string below was recorded from host CPython 3.14.7 (python3)
# before being pinned; any red isolates the exact divergent producer.
#
# NOTE: arms C compare `C.__init__.__kwdefaults__` against the host sentinel
# convention -- real default values and `<factory>` for default_factory --
# NOT the _DC_MISSING placeholder used by the synthesis source itself.

import from objects { PyObj, PyStr, PyCode, PyError, is_error }
import from product_compile { compile_source }
import from pyc_first { exec_code, to_host, unmarshal }
import from host_oracle { host_compile_marshal }
import from dataclassmodule { register_dataclasses_module }


def run_src(src: str) -> str {
    # Compile + VM execute; repr of module global `r`, or "Type: message" when
    # the VM raised (error-arm pins match on the full CPython message).
    co = compile_source(src, "<kw-defaults>", "exec", 0);
    if is_error(co) {
        e = co as PyError;
        return "CompileError: " + str(e.exception.message);
    }
    ns: dict[str, PyObj] = {};
    outcome = exec_code(co as PyCode, [], ns);
    if is_error(outcome) {
        e2 = outcome as PyError;
        return str(e2.exception.type_name) + ": " + str(e2.exception.message);
    }
    if "r" in ns {
        return repr(to_host(ns["r"]));
    }
    return "";
}

def run_dc_src(body: str) -> str {
    # Dataclass facade pathway: native shim module registered first, host
    # compile -> marshal -> unmarshal -> exec_code (same as test_dataclasses).
    register_dataclasses_module();
    co = unmarshal(
        host_compile_marshal(
            "from dataclasses import dataclass, field\n" + body,
            "<kw-defaults-dc>", "exec"
        )
    );
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(co, [], ns);
    if is_error(outcome) {
        return "";
    }
    if "r" in ns {
        return repr(to_host(ns["r"]));
    }
    return "";
}

# ---- A/B: plain functions through MAKE_FUNCTION + attribute protocol ----

test "function kwdefaults: simple table" {
    assert run_src(
        "def foo(p1, p2=0, *, k1, k2=0):\n"
        + "    pass\n"
        + "r = foo.__kwdefaults__\n"
    ) == "{'k2': 0}";
}

test "function kwdefaults: literal value kinds preserved" {
    assert run_src(
        "def g(*, a='x', b=(1, 2), c=None, d=True):\n"
        + "    pass\n"
        + "r = g.__kwdefaults__\n"
    ) == "{'a': 'x', 'b': (1, 2), 'c': None, 'd': True}";
}

test "lambda kwdefaults" {
    assert run_src(
        "h = lambda *, k=5: k\n"
        + "r = h.__kwdefaults__\n"
    ) == "{'k': 5}";
}

test "method kwdefaults: name-mangled key" {
    assert run_src(
        "class X:\n"
        + "    def f(self, *, __a=42):\n"
        + "        return __a\n"
        + "r = X.f.__kwdefaults__\n"
    ) == "{'_X__a': 42}";
}

test "nested function kwdefaults: closure-resolved default value" {
    assert run_src(
        "def outer():\n"
        + "    y = [7]\n"
        + "    def inner(*, m=y[0]):\n"
        + "        pass\n"
        + "    return inner\n"
        + "r = outer().__kwdefaults__\n"
    ) == "{'m': 7}";
}

test "no kw-only defaults -> __kwdefaults__ is None" {
    assert run_src(
        "def nokw(p=1):\n"
        + "    pass\n"
        + "r = nokw.__kwdefaults__\n"
    ) == "None";
}

test "kwdefaults live dict: identity + mutations reach later calls" {
    assert run_src(
        "def f(*, k=[]):\n"
        + "    return k\n"
        + "d = f.__kwdefaults__\n"
        + "d['k'].append(1)\n"
        + "r = (f.__kwdefaults__ is d, f())\n"
    ) == "(True, [1])";
}

test "kwdefaults assignment override replaces the table" {
    assert run_src(
        "def foo(p1, *, k1, k2=0):\n"
        + "    pass\n"
        + "foo.__kwdefaults__ = {'k1': 100}\n"
        + "r = foo.__kwdefaults__\n"
    ) == "{'k1': 100}";
}

test "kwdefaults assignment override drives call resolution" {
    # Host: after the override, k2 has no default left -> exact CPython error.
    assert run_src(
        "def foo(p1, *, k1, k2=0):\n"
        + "    pass\n"
        + "foo.__kwdefaults__ = {'k1': 100}\n"
        + "try:\n"
        + "    foo(1, k1=10)\n"
        + "    r = 'NO-RAISE'\n"
        + "except TypeError as e:\n"
        + "    r = 'TypeError: ' + str(e)\n"
    ) == "TypeError: foo() missing 1 required keyword-only argument: 'k2'";
}

# ---- C: dataclass-generated __init__ ----

test "dataclass __init__: kw_only fields land in kwdefaults, positional in defaults" {
    # Host: ((2,), {'c': 3, 'd': <factory>}) -- real default value for c,
    # the factory sentinel for d.
    assert run_dc_src(
        "@dataclass\n"
        + "class C:\n"
        + "    a: int\n"
        + "    b: int = 2\n"
        + "    c: int = field(default=3, kw_only=True)\n"
        + "    d: int = field(default_factory=list, kw_only=True)\n"
        + "r = (C.__init__.__defaults__, C.__init__.__kwdefaults__)\n"
    ) == "((2,), {'c': 3, 'd': <factory>})";
}

test "dataclass __init__: default_factory yields fresh object per call" {
    assert run_dc_src(
        "@dataclass\n"
        + "class C:\n"
        + "    a: int\n"
        + "    c: int = field(default=3, kw_only=True)\n"
        + "    d: list = field(default_factory=list, kw_only=True)\n"
        + "c1 = C(1)\n"
        + "c2 = C(1)\n"
        + "r = (c1.d == [], c2.d == [], c1.d is c2.d)\n"
    ) == "(True, True, False)";
}

test "dataclass(kw_only=True) __init__: all fields in kwdefaults" {
    assert run_dc_src(
        "@dataclass(kw_only=True)\n"
        + "class K:\n"
        + "    x: int = 9\n"
        + "    y: str = 'z'\n"
        + "r = K.__init__.__kwdefaults__\n"
    ) == "{'x': 9, 'y': 'z'}";
}

test "dataclass(kw_only=True): kw defaults drive construction" {
    assert run_dc_src(
        "@dataclass(kw_only=True)\n"
        + "class K:\n"
        + "    x: int = 9\n"
        + "    y: str = 'z'\n"
        + "r = K(x=9, y='w').y\n"
    ) == "'w'";
}

test "dataclass __init__: no kw_only fields -> kwdefaults is None" {
    assert run_dc_src(
        "@dataclass\n"
        + "class P:\n"
        + "    a: int = 1\n"
        + "    b: str = 'q'\n"
        + "r = P.__init__.__kwdefaults__\n"
    ) == "None";
}

test "dataclass __init__: mixed positional defaults + trailing kw_only field" {
    assert run_dc_src(
        "@dataclass\n"
        + "class Q:\n"
        + "    a: int = 1\n"
        + "    b: str = field(default='q', kw_only=True)\n"
        + "r = Q.__init__.__kwdefaults__\n"
    ) == "{'b': 'q'}";
}
