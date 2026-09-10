# Runtime compilation routes: host bootstrap or JacPython compiler.

import marshal;

import from jaclang.runtime.python.objects { PyObj, is_error, py_error, py_none }
import from jaclang.runtime.python.marshal_reader { unmarshal }
import from jaclang.compiler.backends.py.jacpython.product_compile { compile_source }

enum CompileRoute {
    BOOTSTRAP,
    NATIVE,
}

# List holders: scalar globs rebound inside a function are scoped local and
# never persist (same pattern as layer3_flag in ceval.jac).
glob compile_route_slot: list[CompileRoute] = [CompileRoute.BOOTSTRAP];

def set_compile_route_active(route: CompileRoute) {
    compile_route_slot[0] = route;
}

# Call at every host source compile/marshal entry. Returns py_none() when
# allowed, PyError when the NATIVE route would be violated.
def note_host_source_marshal -> PyObj {
    if compile_route_slot[0] == CompileRoute.NATIVE {
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
