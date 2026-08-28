# ceval import opcode handlers (jac-py/PLAN.md §4).
# ceval_exec_frame.jac dispatches via try_dispatch_imports + apply_opcode_outcome.

import from objects {
    PyObj, PyInt, PyStr, PyError, py_none, py_error, is_error,
}
import from opcode_meta { OP_IMPORT_FROM, OP_IMPORT_NAME, }
import from ceval_exceptions { recover_exception, }
import from ceval {
    layer3_is_active, py_import_name, host_import, py_attr,
}

def try_dispatch_imports(
    op: int,
    arg: int,
    stack: list[PyObj],
    co: PyCode,
    offset: int,
    globals: dict[str, PyObj],
) -> tuple[bool, tuple[int, PyObj]] {
    if op == OP_IMPORT_NAME {
        fromlist = stack.pop();
        level_obj = stack.pop();
        result = py_none();
        if layer3_is_active() {
            import_level = 0;
            if isinstance(level_obj, PyInt) {
                import_level = (level_obj as PyInt).val;
            }
            result = py_import_name(co.names[arg], fromlist, import_level, globals);
        } else {
            result = host_import(co.names[arg], fromlist);
        }
        if is_error(result) {
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, result));
        }
        stack.append(result);
        return (True, (-1, py_none()));
    }
    if op == OP_IMPORT_FROM {
        module = stack[len(stack) - 1];
        result = py_attr(module, co.names[arg]);
        if is_error(result) {
            exc = (result as PyError).exception;
            if exc.type_name == "AttributeError" {
                modname = "<unknown>";
                nmobj = py_attr(module, "__name__");
                if not is_error(nmobj) and isinstance(nmobj, PyStr) {
                    modname = (nmobj as PyStr).val;
                }
                origin = "";
                fileobj = py_attr(module, "__file__");
                if not is_error(fileobj) and isinstance(fileobj, PyStr) {
                    origin = (fileobj as PyStr).val;
                }
                if origin != "" {
                    result = py_error(
                        "ImportError",
                        "cannot import name '" + co.names[arg] + "' from '"
                            + modname + "' (" + origin + ")"
                    );
                } else {
                    result = py_error(
                        "ImportError",
                        "cannot import name '" + co.names[arg] + "' from '"
                            + modname + "'"
                    );
                }
            }
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, result));
        }
        stack.append(result);
        return (True, (-1, py_none()));
    }
    return (False, (-1, py_none()));
}
