# Phase 0/1 runtime-mode contract pins (PLAN.md).
#
# Proves ORACLE/BOOTSTRAP/NATIVE routing, native import/exec on the product
# path, and hard failure when host source marshal is reached from NATIVE.

import os;
import pathlib;
import shutil;
import sys;
import tempfile;
import from pyc_first {
    clear_sys3_modules,
    set_layer3_active,
    import_native,
    exec_code,
    host_compile_marshal,
    py_attr,
    py_invoke,
    to_host,
}
import from dataclassmodule { dc_make_fn }
import from compile_route {
    CompileRoute,
    compile_source_routed,
    get_compile_route_active,
    set_compile_route_active,
    host_source_marshal_invocations,
    native_host_marshal_violation,
    note_host_source_marshal,
    reset_host_source_marshal_stats,
}
import from objects {
    PyObj,
    PyCode,
    PyError,
    PyStr,
    PyInt,
    is_error,
    expect_int,
}

def _fail(outcome: PyObj) -> str {
    exc = (outcome as PyError).exception;
    return exc.type_name + ": " + exc.message;
}

test "runtime_mode: NATIVE route rejects host source marshal" {
    reset_host_source_marshal_stats();
    prev = get_compile_route_active();
    set_compile_route_active(CompileRoute.NATIVE);
    chk = note_host_source_marshal();
    set_compile_route_active(prev);
    assert is_error(chk), "expected host marshal guard to fail on NATIVE route";
    assert native_host_marshal_violation();
    assert host_source_marshal_invocations() == 1;
}

test "runtime_mode: pyc_first bootstrap transport tripwire rejects NATIVE" {
    reset_host_source_marshal_stats();
    prev = get_compile_route_active();
    set_compile_route_active(CompileRoute.NATIVE);
    outcome = host_compile_marshal("x = 1\n");
    set_compile_route_active(prev);
    assert is_error(outcome), "expected pyc_first host_compile_marshal to fail on NATIVE route";
    assert native_host_marshal_violation();
    assert host_source_marshal_invocations() == 1;
}

test "runtime_mode: dataclass template compile tripwire rejects NATIVE" {
    reset_host_source_marshal_stats();
    prev = get_compile_route_active();
    set_compile_route_active(CompileRoute.NATIVE);
    outcome = dc_make_fn({}, "def f():\n    pass\n", "f");
    set_compile_route_active(prev);
    assert is_error(outcome), "expected dataclass template compile to fail on NATIVE route";
    assert native_host_marshal_violation();
    assert host_source_marshal_invocations() == 1;
}

test "runtime_mode: native import of closure-containing module" {
    reset_host_source_marshal_stats();
    base = tempfile.mkdtemp(prefix="jac_native_import_");
    pathlib.Path(base + "/closure_mod.py").write_text(
        "def make_adder(n):\n"
        "    def add(x):\n"
        "        return x + n\n"
        "    return add\n"
        "ADD5 = make_adder(5)\n"
    );
    sys.path.insert(0, base);
    clear_sys3_modules();
    set_layer3_active(True);
    mod = import_native("closure_mod");
    sys.path.pop(0);
    shutil.rmtree(base, ignore_errors=True);
    assert not is_error(mod), _fail(mod);
    add5 = py_attr(mod, "ADD5");
    outcome = py_invoke(add5, [PyInt(t="int", val=10)], {});
    assert not is_error(outcome), _fail(outcome);
    assert expect_int(outcome) == 15;
    assert host_source_marshal_invocations() == 0;
    assert not native_host_marshal_violation();
}

test "runtime_mode: native exec with caller globals and locals" {
    reset_host_source_marshal_stats();
    clear_sys3_modules();
    set_layer3_active(True);
    co = compile_source_routed(
        "g = {'base': 10}\n"
        "l = {}\n"
        "exec('w = base + 5\\n', g, l)\n"
        "result = (g.get('w'), l.get('w'))\n",
        "<runtime_mode_exec>",
        "exec",
        0,
        CompileRoute.NATIVE
    );
    assert not is_error(co), _fail(co);
    ns: dict[str, PyObj] = {};
    outcome = exec_code(co as PyCode, [], ns);
    assert not is_error(outcome), _fail(outcome);
    assert to_host(ns["result"]) == (None, 15);
    assert host_source_marshal_invocations() == 0;
    assert not native_host_marshal_violation();
}
