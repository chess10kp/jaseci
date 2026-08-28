# ceval load/store/call/attribute opcode handlers (jac-py/PLAN.md §4).
# LOAD_*/STORE_*/CALL_* and attribute opcodes from run_frame_inner.
# ceval_exec_frame.jac dispatches via try_dispatch_loadcall + apply_opcode_outcome.

import from objects {
    PyObj, PyInt, PyStr, PyBool, PyNoneType, PyCode, PyCell, PyDict, PyTuple,
    PyList, PyFunction, PyTypeVar, PyTypeAlias, PyBoundMethod, PyNativeBuiltin,
    PyBuildClass, PyAsyncGenWrappedValue, PyGlobalsProxy, PyError, PyException,
    py_none, py_error, is_error, expect_str, str_values, tuple_value,
    dict_from_str_map,
}
import from opcode_meta {
    OP_CALL, OP_CALL_FUNCTION_EX, OP_CALL_INTRINSIC_1, OP_CALL_INTRINSIC_2, OP_CALL_KW, OP_DELETE_ATTR, OP_LOAD_ATTR, OP_LOAD_BUILD_CLASS, OP_LOAD_CLOSURE, OP_LOAD_COMMON_CONSTANT, OP_LOAD_CONST, OP_LOAD_DEREF, OP_LOAD_FAST, OP_LOAD_FAST_AND_CLEAR, OP_LOAD_FAST_BORROW, OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW, OP_LOAD_FAST_CHECK, OP_LOAD_FAST_LOAD_FAST, OP_LOAD_FROM_DICT_OR_DEREF, OP_LOAD_FROM_DICT_OR_GLOBALS, OP_LOAD_GLOBAL, OP_LOAD_LOCALS, OP_LOAD_NAME, OP_LOAD_SMALL_INT, OP_LOAD_SPECIAL, OP_LOAD_SUPER_ATTR, OP_STORE_ATTR, OP_STORE_DEREF, OP_STORE_FAST, OP_STORE_FAST_LOAD_FAST, OP_STORE_FAST_STORE_FAST, OP_STORE_GLOBAL, OP_STORE_NAME,
}
import from ceval_exceptions { recover_exception, }
import from ceval {
    fast_value, fast_value_check, resolve_cell, format_exc_unbound, localsplus_name,
    load_name_fallback, py_attr, py_set_attr, py_del_attr, super_lookup,
    descriptor_get, host_builtin, py_invoke, bind_attribute, builtin_exec,
    py_dir_sorted, members_of, to_host_coerce, from_host,
}

def try_dispatch_loadcall(
    op: int, arg: int, stack: list[PyObj], fast: list[PyObj], assigned: list[bool],
    co: PyCode, offset: int, globals: dict[str, PyObj], locals: dict[str, PyObj],
) -> tuple[bool, tuple[int, PyObj]] {
    if op == OP_LOAD_CONST {
        stack.append(co.consts[arg]);
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_SMALL_INT {
        # oparg is an unsigned int in [0, 256); it is ALWAYS non-negative
        # (CPython emits LOAD_CONST for negative literals). Do NOT sign-extend
        # -- doing so mis-decoded 128..255 as negatives.
        stack.append(PyInt(t="int", val=arg));
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_FAST or op == OP_LOAD_FAST_BORROW {
        fast_result = fast_value(co, arg, fast);
        if is_error(fast_result) {
            return (True, (-2, fast_result));
        }
        stack.append(fast_result);
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_FAST_CHECK {
        fast_result = fast_value_check(co, arg, fast, assigned);
        if is_error(fast_result) {
            return (True, (-2, fast_result));
        }
        stack.append(fast_result);
        return (True, (-1, py_none()));
    }
    if op == OP_STORE_FAST {
        if arg < len(fast) {
            fast[arg] = stack.pop();
            assigned[arg] = True;
            return (True, (-1, py_none()));
        }
        return (True, (-2, py_error("UnboundLocalError", "invalid local variable")));
    }
    if op == OP_LOAD_FAST_AND_CLEAR {
        # Inlined comprehensions save the loop var's outer binding here and
        # clear the slot; a STORE_FAST at the tail restores it. The saved
        # entry is the slot's contents WHOLESALE: for a converted (cell)
        # slot that is the old cell itself, so save/restore also undoes a
        # mid-frame MAKE_CELL exactly like CPython's GETLOCAL/SETLOCAL.
        # NULL (an unbound slot) is modeled with the None placeholder.
        if arg < len(fast) {
            stack.append(fast[arg]);
            fast[arg] = py_none();
        } else {
            stack.append(py_none());
        }
        if arg < len(assigned) {
            assigned[arg] = False;
        }
        return (True, (-1, py_none()));
    }
    if op == OP_STORE_FAST_LOAD_FAST {
        store_index = arg // 16;
        load_index = arg % 16;
        if store_index >= len(fast) {
            return (True, (-2, py_error("UnboundLocalError", "invalid local variable")));
        }
        fast[store_index] = stack.pop();
        assigned[store_index] = True;
        load_result = fast_value(co, load_index, fast);
        if is_error(load_result) {
            return (True, (-2, load_result));
        }
        stack.append(load_result);
        return (True, (-1, py_none()));
    }
    if op == OP_STORE_FAST_STORE_FAST {
        # Packed two-register store: TOS -> reg(arg>>4), TOS1 -> reg(arg&15).
        first_index = arg // 16;
        second_index = arg % 16;
        if first_index >= len(fast) or second_index >= len(fast) {
            return (True, (-2, py_error("UnboundLocalError", "invalid local variable")));
        }
        fast[first_index] = stack.pop();
        assigned[first_index] = True;
        fast[second_index] = stack.pop();
        assigned[second_index] = True;
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW or op == OP_LOAD_FAST_LOAD_FAST {
        first = arg // 16;
        second = arg % 16;
        first_result = fast_value(co, first, fast);
        second_result = fast_value(co, second, fast);
        if is_error(first_result) {
            return (True, (-2, first_result));
        }
        if is_error(second_result) {
            return (True, (-2, second_result));
        }
        stack.append(first_result);
        stack.append(second_result);
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_GLOBAL {
        name_index = arg // 2;
        if name_index >= len(co.names) {
            return (True, (-2, py_error("NameError", "invalid global name")));
        }
        name = co.names[name_index];
        value = py_none();
        if name in globals {
            value = globals[name];
        } else {
            value = load_name_fallback(name);
        }
        if is_error(value) {
            target = recover_exception(co, value, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, value));
        }
        stack.append(value);
        if (arg & 1) != 0 {
            stack.append(py_none());
        }
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_NAME {
        name = co.names[arg];
        value = py_none();
        if name in locals {
            value = locals[name];
        } elif name in globals {
            value = globals[name];
        } else {
            value = load_name_fallback(name);
        }
        if is_error(value) {
            target = recover_exception(co, value, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, value));
        }
        stack.append(value);
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_DEREF {
        cell = resolve_cell(fast, arg);
        if cell is None {
            return (True, (-2, py_error("NameError", "free variable is not set")));
        }
        # An empty cell is distinct from a None binding: emptiness lives on
        # the shared cell object (CPython's cell-NULL check), not the slot.
        if not cell.filled {
            err = format_exc_unbound(co, arg);
            target = recover_exception(co, err, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, err));
        }
        stack.append(cell.val);
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_CLOSURE {
        cell = resolve_cell(fast, arg);
        if cell is None {
            return (True, (-2, py_error("NameError", "free variable is not set")));
        }
        stack.append(cell);
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_FROM_DICT_OR_DEREF {
        # CPython TARGET(LOAD_FROM_DICT_OR_DEREF) (generated_cases.c.h):
        # pop the mapping pushed by LOAD_LOCALS (class namespace), look up
        # the localsplus name; on a miss deref the cell in slot `arg`, and
        # raise the exact unbound error when that is empty too.
        mapping = stack.pop();
        lpname = localsplus_name(co, arg);
        keyname = PyStr(t="str", val=lpname);
        value = py_none();
        hit = False;
        if isinstance(mapping, PyDict) {
            dmap = mapping as PyDict;
            if dmap.dict_contains(keyname) {
                value = dmap.mp_subscript(keyname);
                hit = True;
            }
        } else {
            got = mapping.mp_subscript(keyname);
            if is_error(got) {
                if ((got as PyError).exception.type_name != "KeyError") {
                    target = recover_exception(co, got, offset, stack);
                    if target >= 0 {
                        return (True, (target, py_none()));
                    }
                    return (True, (-2, got));
                }
            } else {
                value = got;
                hit = True;
            }
        }
        if not hit {
            cell = resolve_cell(fast, arg);
            if cell is None or not cell.filled {
                err = format_exc_unbound(co, arg);
                target = recover_exception(co, err, offset, stack);
                if target >= 0 {
                    return (True, (target, py_none()));
                }
                return (True, (-2, err));
            }
            value = cell.val;
        }
        stack.append(value);
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_FROM_DICT_OR_GLOBALS {
        # CPython TARGET(LOAD_FROM_DICT_OR_GLOBALS): pop the module-or-class
        # dict, look up co_names[arg]; on a miss fall back to globals then
        # builtins; still missing -> NAME_ERROR_MSG byte-exact.
        mapping = stack.pop();
        gname = co.names[arg];
        keyname = PyStr(t="str", val=gname);
        value = py_none();
        hit = False;
        if isinstance(mapping, PyDict) {
            dmap = mapping as PyDict;
            if dmap.dict_contains(keyname) {
                value = dmap.mp_subscript(keyname);
                hit = True;
            }
        } else {
            got = mapping.mp_subscript(keyname);
            if is_error(got) {
                if ((got as PyError).exception.type_name != "KeyError") {
                    target = recover_exception(co, got, offset, stack);
                    if target >= 0 {
                        return (True, (target, py_none()));
                    }
                    return (True, (-2, got));
                }
            } else {
                value = got;
                hit = True;
            }
        }
        if not hit {
            if gname in globals {
                value = globals[gname];
            } else {
                value = load_name_fallback(gname);
                if is_error(value) {
                    target = recover_exception(co, value, offset, stack);
                    if target >= 0 {
                        return (True, (target, py_none()));
                    }
                    return (True, (-2, value));
                }
            }
        }
        stack.append(value);
        return (True, (-1, py_none()));
    }
    if op == OP_STORE_DEREF {
        value = stack.pop();
        cell = resolve_cell(fast, arg);
        if cell is None {
            return (True, (-2, py_error("NameError", "free variable is not set")));
        }
        cell.val = value;
        cell.filled = True;
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_LOCALS {
        stack.append(dict_from_str_map(locals));
        return (True, (-1, py_none()));
    }
    if op == OP_STORE_NAME {
        locals[co.names[arg]] = stack.pop();
        return (True, (-1, py_none()));
    }
    if op == OP_STORE_GLOBAL {
        # `global x; x = ...` inside a function -- write straight to the
        # module globals, bypassing the frame's fast/locals.
        globals[co.names[arg]] = stack.pop();
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_BUILD_CLASS {
        stack.append(PyBuildClass(t="build_class"));
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_ATTR {
        owner = stack.pop();
        name = co.names[arg // 2];
        result = py_attr(owner, name);
        if is_error(result) {
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, result));
        }
        if (arg & 1) != 0 {
            stack.append(result);
            stack.append(py_none());
        } else {
            stack.append(result);
        }
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_SUPER_ATTR {
        # Stack (top-down): self, class(__class__ cell), global super. arg
        # encodes name>>2, bit0 = method-call form, bit1 = two-arg super.
        super_self = stack.pop();
        super_class = stack.pop();
        super_global = stack.pop();
        super_name = co.names[arg >> 2];
        result = super_lookup(super_class, super_self, super_name);
        if is_error(result) {
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, result));
        }
        # CPython super_getattro applies the descriptor protocol to what
        # the MRO walk found: a property getter fires against the live
        # instance, a function binds to it, a classmethod binds its class.
        bound = descriptor_get(result, super_self, super_self);
        if (arg & 1) != 0 {
            stack.append(bound);
            stack.append(py_none());
        } else {
            stack.append(bound);
        }
        return (True, (-1, py_none()));
    }
    if op == OP_STORE_ATTR {
        owner = stack.pop();
        field = stack.pop();
        result = py_set_attr(owner, co.names[arg], field);
        if is_error(result) {
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, result));
        }
        return (True, (-1, py_none()));
    }
    if op == OP_DELETE_ATTR {
        owner = stack.pop();
        result = py_del_attr(owner, co.names[arg]);
        if is_error(result) {
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, result));
        }
        return (True, (-1, py_none()));
    }
    if op == OP_CALL or op == OP_CALL_KW {
        keyword_names: list[str] = [];
        call_count = arg;
        if op == OP_CALL_KW {
            names_obj = stack.pop();
            keyword_names = str_values(names_obj);
        }
        call_args: list[PyObj] = [];
        while len(call_args) < call_count {
            call_args.insert(0, stack.pop());
        }
        kwargs_for_call: dict[str, PyObj] = {};
        positional_count_for_call = call_count - len(keyword_names);
        while len(keyword_names) > 0 {
            key = keyword_names.pop();
            kwargs_for_call[key] = call_args.pop();
        }
        if len(stack) == 0 {
            return (True, (-2, py_error("RuntimeError", "CALL stack underflow")));
        }
        self_or_null = stack.pop();
        if len(stack) == 0 {
            return (True, (-2, py_error("RuntimeError", "CALL stack underflow")));
        }
        fn = stack.pop();
        # globals() binds to THIS frame's namespace (a live view), which only
        # the ceval holds -- resolve it here rather than in PyNativeBuiltin.
        if fn.t == "native_builtin" and (fn as PyNativeBuiltin).name == "globals" {
            stack.append(PyGlobalsProxy(t="globals", ns=globals));
            return (True, (-1, py_none()));
        }
        # No-arg dir() answers sorted locals of the CALLING frame -- CPython
        # reads f_locals of its caller, and only this site knows that frame
        # state. Module-level frames pass globals AS locals (exec_code_frame),
        # so a bare dir() at module top level lists module globals, exactly
        # like CPython. Bound localsplus slots join dict-locals keys; a cell
        # slot counts only while filled.
        if fn.t == "native_builtin" and (fn as PyNativeBuiltin).name == "dir"
            and self_or_null.t == "none" and len(call_args) == 0
            and len(kwargs_for_call) == 0 {
            local_names: dict[str, bool] = {};
            for k in locals {
                local_names[k] = True;
            }
            si = 0;
            while si < len(fast) {
                bound = False;
                if isinstance(fast[si], PyCell) {
                    if ((fast[si] as PyCell).filled) {
                        bound = True;
                    }
                } elif si < len(assigned) and assigned[si] {
                    bound = True;
                }
                if bound {
                    local_names[localsplus_name(co, si)] = True;
                }
                si = si + 1;
            }
            stack.append(py_dir_sorted(local_names));
            return (True, (-1, py_none()));
        }
        # exec() must run IN the VM against the LIVE namespace dicts -- see
        # builtin_exec below. Only this call site holds the running frame's
        # globals/locals for the one-argument form.
        if fn.t == "native_builtin" and (fn as PyNativeBuiltin).name == "exec" {
            result = builtin_exec(call_args, kwargs_for_call, globals, locals);
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
        # CPython's CALL convention carries a `self_or_null` slot below the
        # args. NULL (a plain call after PUSH_NULL, modeled here as None) is
        # dropped; a real value (a bound self, or a genexpr's `.0` iterator
        # under `CALL 0`) is prepended as the first positional argument.
        if self_or_null.t != "none" {
            call_args.insert(0, self_or_null);
        }
        result = py_invoke(fn, call_args, kwargs_for_call);
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
    if op == OP_CALL_FUNCTION_EX {
        # f(*args, **kwargs). Stack (bottom->top): func, self_or_null,
        # callargs (a materialized iterable), kwargs (a mapping or NULL). The
        # oparg is unused in 3.14: a NULL kwargs slot (PUSH_NULL) means no
        # keywords.
        kwargs_obj = stack.pop();
        callargs_obj = stack.pop();
        self_or_null_ex = stack.pop();
        fn_ex = stack.pop();
        ex_args_list = members_of(callargs_obj);
        if is_error(ex_args_list) {
            # members_of TypeError (non-iterable *args) must dispatch to a
            # same-frame handler.
            target = recover_exception(co, ex_args_list, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, ex_args_list));
        }
        ex_call_args: list[PyObj] = (ex_args_list as PyList).items;
        if self_or_null_ex.t != "none" {
            ex_call_args.insert(0, self_or_null_ex);
        }
        ex_kwargs: dict[str, PyObj] = {};
        if isinstance(kwargs_obj, PyDict) {
            ex_kwargs = (kwargs_obj as PyDict).dict_str_map();
        } elif kwargs_obj.t != "none" {
            # A non-dict, non-NULL mapping (e.g. a proxied host mapping):
            # normalize through from_host(to_host(...)) into a PyDict.
            hkw_r = to_host_coerce(kwargs_obj);
            hkw = hkw_r[1];
            if not ((hkw_r[0] as bool)) {
                return (True, (-2, hkw_r[1] as PyObj));
            }
            coerced = from_host(hkw);
            if isinstance(coerced, PyDict) {
                ex_kwargs = (coerced as PyDict).dict_str_map();
            }
        }
        ex_result = py_invoke(fn_ex, ex_call_args, ex_kwargs);
        if is_error(ex_result) {
            target = recover_exception(co, ex_result, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, ex_result));
        }
        stack.append(ex_result);
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_SPECIAL {
        # LOAD_SPECIAL macro (_INSERT_NULL + _LOAD_SPECIAL): pop the context
        # manager, look up __enter__/__exit__, push [func, self_or_null] for
        # the CALL convention (method descriptors keep the owner as self).
        if len(stack) < 1 {
            return (True, (-2, py_error("RuntimeError", "LOAD_SPECIAL stack underflow")));
        }
        owner = stack.pop();
        spec_name = "__enter__";
        if arg == 1 {
            spec_name = "__exit__";
        } elif arg == 2 {
            spec_name = "__aenter__";
        } elif arg == 3 {
            spec_name = "__aexit__";
        }
        method = py_attr(owner, spec_name);
        if is_error(method) {
            target = recover_exception(co, method, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, method));
        }
        if isinstance(method, PyBoundMethod) {
            bm = method as PyBoundMethod;
            stack.append(bm.function);
            stack.append(bm.receiver);
        } else {
            stack.append(method);
            stack.append(owner);
        }
        return (True, (-1, py_none()));
    }
    if op == OP_LOAD_COMMON_CONSTANT {
        # _common_constants: [AssertionError, NotImplementedError, tuple,
        # all, any]. Resolved through host_builtin so an identity check like
        # `tuple is <common tuple>` (the tuple()/frozenset() genexpr fast
        # path) sees the same host-proxy tag on both sides.
        common_name = "tuple";
        if arg == 0 {
            common_name = "AssertionError";
        } elif arg == 1 {
            common_name = "NotImplementedError";
        } elif arg == 3 {
            common_name = "all";
        } elif arg == 4 {
            common_name = "any";
        }
        stack.append(host_builtin(common_name));
        return (True, (-1, py_none()));
    }
    if op == OP_CALL_INTRINSIC_1 {
        operand = stack.pop();
        if arg == 6 {
            # INTRINSIC_LIST_TO_TUPLE: the tuple()-of-genexpr fast path
            # builds a list, then converts it in place.
            stack.append(PyTuple(t="tuple", items=(operand as PyList).items));
            return (True, (-1, py_none()));
        }
        if arg == 7 {
            # INTRINSIC_TYPEVAR (PEP 695 type parameter): operand is just
            # the parameter name string. Bounds/constraints never come
            # through here -- codegen wraps an unparameterized TypeVar via
            # CALL_INTRINSIC_2 TYPEVAR_WITH_BOUND/_WITH_CONSTRAINTS.
            if not isinstance(operand, PyStr) {
                return (True, (-2, py_error("SystemError", "CALL_INTRINSIC_1 TYPEVAR name must be a str")));
            }
            stack.append(PyTypeVar(t="TypeVar", name=(operand as PyStr).val));
            return (True, (-1, py_none()));
        }
        if arg == 4 {
            # INTRINSIC_ASYNC_GEN_WRAP: CPython wraps each async-generator
            # yield in an AsyncGenWrappedValue so the anext/asend machinery
            # can tell yields from returns. The agen_* drivers unwrap it;
            # a wrapped value escaping any other path stays observable and
            # inert (same policy as CPython's opaque wrapper object).
            stack.append(PyAsyncGenWrappedValue(t="async_wrapped", val=operand));
            return (True, (-1, py_none()));
        }
        if arg == 11 {
            # INTRINSIC_TYPEALIAS (PEP 695 `type X = v`): operand is the
            # (name, type_params_or_None, lazy-value-fn) triple codegen
            # builds. Produce the lazily-evaluating alias object.
            if not isinstance(operand, PyTuple)
                or len((operand as PyTuple).items) != 3 {
                return (True, (-2, py_error("SystemError", "malformed CALL_INTRINSIC_1 TYPEALIAS operand")));
            }
            parts = (operand as PyTuple).items;
            if not isinstance(parts[0], PyStr) {
                return (True, (-2, py_error("SystemError", "CALL_INTRINSIC_1 TYPEALIAS name must be a str")));
            }
            stack.append(PyTypeAlias(
                t="TypeAliasType",
                name=(parts[0] as PyStr).val,
                type_params=parts[1],
                value_fn=parts[2],
            ));
            return (True, (-1, py_none()));
        }
        if arg == 3 {
            # INTRINSIC_STOPITERATION_ERROR (PEP 479): the pending exception
            # is on the stack. A StopIteration escaping a generator body is
            # converted to RuntimeError; everything else passes through. The
            # following RERAISE propagates whatever we push back.
            exc_name = "";
            if operand.t == "exception" {
                exc_name = (operand as PyException).type_name;
            }
            if exc_name == "StopIteration" {
                stack.append(
                    PyException(
                        t="exception",
                        type_name="RuntimeError",
                        message="generator raised StopIteration",
                    )
                );
            } else {
                stack.append(operand);
            }
            return (True, (-1, py_none()));
        }
        if arg == 5 {
            # INTRINSIC_UNARY_POSITIVE
            stack.append(operand);
            return (True, (-1, py_none()));
        }
        if arg == 2 {
            # INTRINSIC_IMPORT_STAR: `from module import *` binds the module's
            # exported names into the current globals. (Layer 3 only.)
            star_out = import_star_into(operand, globals);
            if is_error(star_out) {
                target = recover_exception(co, star_out, offset, stack);
                if target >= 0 {
                    return (True, (target, py_none()));
                }
                return (True, (-2, star_out));
            }
            # CPython pushes None for the following POP_TOP.
            stack.append(py_none());
            return (True, (-1, py_none()));
        }
        if arg == 10 {
            # INTRINSIC_SUBSCRIPT_GENERIC (implicit PEP 695 class base):
            # operand is the type-parameter tuple; produce the
            # typing.Generic[T, ...] stand-in that py_build_class later
            # resolves through __mro_entries__ (update_build_class_bases).
            if not isinstance(operand, PyTuple) {
                return (True, (-2, py_error("SystemError", "malformed CALL_INTRINSIC_1 SUBSCRIPT_GENERIC operand")));
            }
            stack.append(PyGenericAlias(t="generic_alias", params=operand));
            return (True, (-1, py_none()));
        }
        return (True, (-2, py_error("SystemError", "unsupported CALL_INTRINSIC_1 " + str(arg))));
    }
    if op == OP_CALL_INTRINSIC_2 {
        rhs = stack.pop();
        lhs = stack.pop();
        if arg == 1 {
            # INTRINSIC_PREP_RERAISE_STAR: (orig, excs-list) -> the
            # exception to reraise at the tail of a lowered try/except*
            # block (None when everything was swallowed). Semantics live
            # in exceptions_core.prep_reraise_star (_PyExc_PrepReraiseStar
            # port); zero logic inline.
            rr_prep = prep_reraise_star(lhs, rhs);
            if is_error(rr_prep) {
                return (True, (-2, rr_prep));
            }
            stack.append(rr_prep);
            return (True, (-1, py_none()));
        }
        if arg == 2 {
            # INTRINSIC_TYPEVAR_WITH_BOUND: (name, lazy-bound-evaluator).
            # The bound stays unevaluated until first __bound__ access --
            # see typevar_bound_value in py_attr.
            if not isinstance(lhs, PyStr) {
                return (True, (-2, py_error("SystemError", "malformed CALL_INTRINSIC_2 TYPEVAR_WITH_BOUND operand")));
            }
            stack.append(PyTypeVar(
                t="TypeVar", name=(lhs as PyStr).val, evaluate_bound=rhs
            ));
            return (True, (-1, py_none()));
        }
        if arg == 3 {
            # INTRINSIC_TYPEVAR_WITH_CONSTRAINTS: (name, lazy-constraints).
            if not isinstance(lhs, PyStr) {
                return (True, (-2, py_error("SystemError", "malformed CALL_INTRINSIC_2 TYPEVAR_WITH_CONSTRAINTS operand")));
            }
            stack.append(PyTypeVar(
                t="TypeVar", name=(lhs as PyStr).val, evaluate_constraints=rhs
            ));
            return (True, (-1, py_none()));
        }
        if arg == 4 {
            # INTRINSIC_SET_FUNCTION_TYPE_PARAMS: (function, params-tuple);
            # CPython stores func_typeparams and returns the function.
            if not isinstance(lhs, PyFunction) or not isinstance(rhs, PyTuple) {
                return (True, (-2, py_error("SystemError", "malformed CALL_INTRINSIC_2 SET_FUNCTION_TYPE_PARAMS operands")));
            }
            fn_tps = lhs as PyFunction;
            fn_tps.attrs["__type_params__"] = rhs;
            stack.append(fn_tps);
            return (True, (-1, py_none()));
        }
        if arg == 5 {
            # INTRINSIC_SET_TYPEPARAM_DEFAULT: (typeparam,
            # lazy-default-evaluator); evaluated on first __default__
            # access -- see typevar_default_value in py_attr.
            if not isinstance(lhs, PyTypeVar) {
                return (True, (-2, py_error("SystemError", "malformed CALL_INTRINSIC_2 SET_TYPEPARAM_DEFAULT operand")));
            }
            tp_default = lhs as PyTypeVar;
            tp_default.evaluate_default = rhs;
            stack.append(tp_default);
            return (True, (-1, py_none()));
        }
        return (True, (-2, py_error("SystemError", "unsupported CALL_INTRINSIC_2 " + str(arg))));
    }
    return (False, (-1, py_none()));
}
