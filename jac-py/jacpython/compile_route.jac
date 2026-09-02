# Runtime compilation route contract (PLAN.md Phase 0).
#
# ORACLE: host CPython compilation for differential tests only -- lives in
# host_oracle.jac, which product code must never import (P4 import gate).
# Product routing implements NATIVE and BOOTSTRAP and rejects ORACLE.
# BOOTSTRAP: narrowly scoped startup transport (in-process host compile+marshal).
# NATIVE: Jac parser/compiler/assembler output (product_compile).
#
# Every source-compilation call site must declare its route. Host source marshal
# entry points increment host_source_marshal_invocations and hard-fail when the
# active route is NATIVE.

import marshal;

import from objects { PyObj, is_error, py_error, py_none }
import from marshal_reader { unmarshal }
import from product_compile { compile_source }

enum CompileRoute {
    ORACLE,
    BOOTSTRAP,
    NATIVE,
}

# List holders: scalar globs rebound inside a function are scoped local and
# never persist (same pattern as layer3_flag in ceval.jac).
glob compile_route_slot: list[CompileRoute] = [CompileRoute.BOOTSTRAP],
     host_source_marshal_count: list[int] = [0],
     native_host_marshal_violation_flag: list[bool] = [False];

def reset_host_source_marshal_stats {
    host_source_marshal_count[0] = 0;
    native_host_marshal_violation_flag[0] = False;
}

def host_source_marshal_invocations -> int {
    return host_source_marshal_count[0];
}

def native_host_marshal_violation -> bool {
    return native_host_marshal_violation_flag[0];
}

def host_source_marshal_allowed -> bool {
    return compile_route_slot[0] != CompileRoute.NATIVE;
}

def get_compile_route_active -> CompileRoute {
    return compile_route_slot[0];
}

def set_compile_route_active(route: CompileRoute) {
    compile_route_slot[0] = route;
}

# Call at every host source compile/marshal entry. Returns py_none() when
# allowed, PyError when the NATIVE route would be violated.
def note_host_source_marshal -> PyObj {
    host_source_marshal_count[0] = host_source_marshal_count[0] + 1;
    if compile_route_slot[0] == CompileRoute.NATIVE {
        native_host_marshal_violation_flag[0] = True;
        return py_error(
            "RuntimeError",
            "NATIVE compilation route reached host source marshal"
        );
    }
    return py_none();
}

def _bootstrap_source_marshal(source: str) -> list[int] {
    raw = marshal.dumps(compile(source, "<jacpython-bootstrap>", "exec"));
    return raw as list[int];
}

def compile_source_routed(
    source: str, filename: str, mode: str, optimize: int, route: CompileRoute
) -> PyObj {
    prev = compile_route_slot[0];
    compile_route_slot[0] = route;
    result: PyObj;
    if route == CompileRoute.NATIVE {
        result = compile_source(source, filename, mode, optimize);
    } elif route == CompileRoute.ORACLE {
        # Test-only mode: the host oracle lives in host_oracle.jac, which
        # product code must not import (P4 import gate). Reaching for it
        # through product routing is a layering violation.
        result = py_error(
            "RuntimeError",
            "ORACLE route is test-only; call host_oracle directly in tests"
        );
    } else {
        chk = note_host_source_marshal();
        if is_error(chk) {
            compile_route_slot[0] = prev;
            return chk;
        }
        result = unmarshal(_bootstrap_source_marshal(source));
    }
    compile_route_slot[0] = prev;
    return result;
}
