# ceval exec frame + opcode dispatch (jac-py/PLAN.md §4 module-boundary constraint).
# exec_code_frame, run_frame/run_frame_inner, and the main opcode dispatch loop.
# ceval.jac imports this module; must not import pyc_first.

import from abstract_protocol { PyIter_Check, }
import from exceptions_core {
    exc_name_matches,
    prep_reraise_star,
    baseexception_str,
    baseexception_repr,
}
import from objects {
    PyObj,
    PyInt,
    PyStr,
    PyBool,
    PyNoneType,
    PyCode,
    PyCell,
    PyDict,
    PyTuple,
    PyList,
    PySet,
    PySlice,
    PyError,
    PyException,
    PyTypeVar,
    PyTypeAlias,
    PyDictIter,
    PyCallableIter,
    PySeqIter,
    find_name,
    expect_str,
    str_values,
    tuple_value,
    py_none,
    py_error,
    py_exception_type,
    is_error,
}
import from ceval_exceptions {
    recover_exception,
    dispatch_exception,
    except_target_valid,
    exception_matches,
    eg_validate_star_target,
    exception_group_split,
    error_is_stopiteration,
}
import from ceval_opcodes_containers {
    op_build_list,
    op_build_map,
    op_build_set,
    op_set_update,
    op_list_extend,
    op_list_append,
    op_set_add,
    op_map_add,
    op_dict_update,
    op_dict_merge,
    op_binary_subscript,
    op_binary_slice,
    op_store_slice,
    op_store_subscr,
    op_delete_subscr,
}
import from opcode_meta {
    OP_CACHE,
    OP_RESUME,
    OP_LOAD_BUILD_CLASS,
    OP_LOAD_LOCALS,
    OP_LOAD_FROM_DICT_OR_DEREF,
    OP_LOAD_FROM_DICT_OR_GLOBALS,
    OP_NOT_TAKEN,
    OP_SETUP_ANNOTATIONS,
    OP_POP_TOP,
    OP_PUSH_EXC_INFO,
    OP_PUSH_NULL,
    OP_RETURN_VALUE,
    OP_BINARY_SLICE,
    OP_BUILD_SLICE,
    OP_STORE_SLICE,
    OP_CHECK_EG_MATCH,
    OP_STORE_SUBSCR,
    OP_UNARY_NOT,
    OP_WITH_EXCEPT_START,
    OP_BINARY_OP,
    OP_BUILD_LIST,
    OP_BUILD_MAP,
    OP_BUILD_TUPLE,
    OP_BUILD_INTERPOLATION,
    OP_BUILD_TEMPLATE,
    OP_CALL,
    OP_CALL_KW,
    OP_COMPARE_OP,
    OP_COPY,
    OP_COPY_FREE_VARS,
    OP_END_FOR,
    OP_END_ASYNC_FOR,
    OP_GET_AITER,
    OP_GET_ANEXT,
    OP_GET_ITER,
    OP_IMPORT_FROM,
    OP_IMPORT_NAME,
    OP_IS_OP,
    OP_JUMP_BACKWARD,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_JUMP_FORWARD,
    OP_LIST_APPEND,
    OP_SET_ADD,
    OP_LIST_EXTEND,
    OP_LOAD_ATTR,
    OP_LOAD_SUPER_ATTR,
    OP_LOAD_CONST,
    OP_LOAD_DEREF,
    OP_LOAD_CLOSURE,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_CHECK,
    OP_LOAD_FAST_LOAD_FAST,
    OP_LOAD_GLOBAL,
    OP_LOAD_NAME,
    OP_LOAD_SMALL_INT,
    OP_LOAD_SPECIAL,
    OP_MAKE_CELL,
    OP_MAKE_FUNCTION,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_JUMP_IF_TRUE,
    OP_RAISE_VARARGS,
    OP_RERAISE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_STORE_ATTR,
    OP_DELETE_ATTR,
    OP_DELETE_DEREF,
    OP_STORE_DEREF,
    OP_STORE_FAST,
    OP_DELETE_FAST,
    OP_STORE_NAME,
    OP_STORE_GLOBAL,
    OP_DELETE_GLOBAL,
    OP_DELETE_NAME,
    OP_SWAP,
    OP_CHECK_EXC_MATCH,
    OP_POP_EXCEPT,
    OP_BUILD_SET,
    OP_SET_UPDATE,
    OP_CONVERT_VALUE,
    OP_FORMAT_SIMPLE,
    OP_FORMAT_WITH_SPEC,
    OP_BUILD_STRING,
    OP_RETURN_GENERATOR,
    OP_YIELD_VALUE,
    OP_STORE_FAST_LOAD_FAST,
    OP_TO_BOOL,
    OP_CONTAINS_OP,
    OP_LOAD_COMMON_CONSTANT,
    OP_CALL_INTRINSIC_1,
    OP_CALL_INTRINSIC_2,
    OP_LOAD_FAST_AND_CLEAR,
    OP_SEND,
    OP_END_SEND,
    OP_GET_YIELD_FROM_ITER,
    OP_GET_AWAITABLE,
    OP_CLEANUP_THROW,
    OP_UNARY_NEGATIVE,
    OP_UNARY_INVERT,
    OP_UNPACK_SEQUENCE,
    OP_UNPACK_EX,
    OP_GET_LEN,
    OP_MATCH_SEQUENCE,
    OP_MATCH_MAPPING,
    OP_MATCH_KEYS,
    OP_MATCH_CLASS,
    OP_DELETE_SUBSCR,
    OP_MAP_ADD,
    OP_DICT_MERGE,
    OP_DICT_UPDATE,
    OP_STORE_FAST_STORE_FAST,
    OP_EXTENDED_ARG,
    OP_CALL_FUNCTION_EX,
    OP_NOP,
    OP_FOR_ITER,
    OP_POP_ITER,
    opcode_cache_count,
}
import from ceval_defs {
    _handled_exc_stack,
    _handled_stack_append_each,
    _handled_stack_remove_each,
    PyFrame,
    PyGenerator,
    PyYield,
    PyHostProxy,
    PyUserObj,
    PyFunction,
    PyGenStop,
    PyBuildClass,
    PyAsyncGenWrappedValue,
    PyGlobalsProxy,
    PyBoundMethod,
    PyNativeBuiltin,
    PyGenericAlias,
}
import from ceval_api {
    builtin_exec,
    dict_from_str_map,
    fast_value,
    fast_value_check,
    format_exc_unbound,
    localsplus_name,
    resolve_cell,
    make_function_from_stack,
    make_interpolation,
    make_template,
    members_of,
    descriptor_get,
    host_builtin,
    host_convert,
    host_format,
    host_import,
    import_star_into,
    layer3_is_active,
    load_name_fallback,
    gen_resume,
    send_into,
    send_throw_into,
    calliter_next,
    seqiter_next,
    dictiter_yield,
    dictiter_error,
    py_import_name,
    py_slot_truth,
    py_repr,
    py_str,
    py_compare,
    py_contains,
    py_binop,
    py_attr,
    py_set_attr,
    py_del_attr,
    py_invoke,
    py_iter,
    py_len,
    py_negative,
    py_invert,
    py_raise_value,
    py_get_awaitable,
    py_aiter,
    py_anext,
    py_match_class,
    py_match_keys,
    py_type_has_sequence_flag,
    py_type_has_mapping_flag,
    py_identity,
    py_dir_sorted,
    bind_attribute,
    super_lookup,
    user_has_dunder,
    call_user_dunder,
    from_host,
    to_host_coerce,
}


import from vm_dispatch { jac_frame_chain_slot_ref, }

def jac_current_frame -> PyFrame | None {
    if len(jac_frame_chain_slot_ref()) == 0 {
        return None;
    }
    return jac_frame_chain_slot_ref()[len(jac_frame_chain_slot_ref()) - 1];
}

def exec_code_frame(
    co: PyCode,
    args: list[PyObj],
    kwargs: dict[str, PyObj],
    globals: dict[str, PyObj],
    locals: dict[str, PyObj],
    closure: list[PyCell],
    defaults: list[PyObj],
    kwdefaults: dict[str, PyObj]
) -> PyObj {
    fast: list[PyObj] = [];
    assigned: list[bool] = [];
    i = 0;
    while i < len(co.varnames) {
        fast.append(py_none());
        assigned.append(False);
        i = i + 1;
    }
    positional_count = co.argcount;
    has_varargs = (co.flags & 4) != 0;
    has_varkw = (co.flags & 8) != 0;
    # Named-parameter slots occupy [0 .. argcount + kwonlyargcount); the *args and
    # **kwargs slots (when present) follow, in that order (CPython's localsplus
    # layout). Keywords that don't name a parameter belong in **kwargs.
    param_slots = positional_count + co.kwonlyargcount;
    i = 0;
    while i < len(args) and i < positional_count {
        fast[i] = args[i];
        assigned[i] = True;
        i = i + 1;
    }
    if has_varargs {
        # Surplus positionals gather into the *args tuple slot.
        extra: list[PyObj] = [];
        j = positional_count;
        while j < len(args) {
            extra.append(args[j]);
            j = j + 1;
        }
        fast[param_slots] = PyTuple(t="tuple", items=extra);
        assigned[param_slots] = True;
    } elif len(args) > positional_count {
        return py_error("TypeError", "too many positional arguments");
    }
    varkw_slot = -1;
    if has_varkw {
        varkw_slot = param_slots;
        if has_varargs {
            varkw_slot = varkw_slot + 1;
        }
        fast[varkw_slot] = PyDict(t="dict", items={});
        assigned[varkw_slot] = True;
    }
    for key in kwargs {
        index = find_name(co.varnames, key);
        # A keyword binds a named parameter only if it lands in the parameter
        # region and isn't positional-only; otherwise it flows into **kwargs (or
        # is an error when the function has none).
        is_param = index >= 0 and index < param_slots and index >= co.posonlyargcount;
        if is_param and assigned[index] {
            return py_error("TypeError", "multiple values for argument " + key);
        }
        if is_param {
            fast[index] = kwargs[key];
            assigned[index] = True;
        } elif has_varkw {
            (fast[varkw_slot] as PyDict).dict_set(PyStr(t="str", val=key), kwargs[key]);
        } elif index >= 0 and index < co.posonlyargcount {
            return py_error("TypeError", "positional-only argument passed by name");
        } else {
            return py_error("TypeError", "unexpected keyword argument " + key);
        }
    }
    i = 0;
    while i < positional_count {
        if not assigned[i] {
            default_index = i - (positional_count - len(defaults));
            if default_index >= 0 and default_index < len(defaults) {
                fast[i] = defaults[default_index];
                assigned[i] = True;
            }
        }
        if not assigned[i] {
            return py_error("TypeError", "missing required argument");
        }
        i = i + 1;
    }
    i = 0;
    while i < co.kwonlyargcount {
        index = positional_count + i;
        if not assigned[index] {
            key = co.varnames[index];
            if key in kwdefaults {
                fast[index] = kwdefaults[key];
                assigned[index] = True;
            }
        }
        if not assigned[index] {
            return py_error("TypeError", "missing required keyword argument");
        }
        i = i + 1;
    }

    # Extend the varname region into the full merged localsplus: cellvars that
    # share a varname slot convert that slot in place to a cell wrapping the
    # already-bound argument/local value (the runtime effect of the prologue
    # MAKE_CELLs); remaining cellvars append their cells in cellvar order, then
    # the freevar (closure) cells append -- CPython's exact layout.
    ci = 0;
    while ci < len(co.cellvars) {
        fast_index = find_name(co.varnames, co.cellvars[ci]);
        if fast_index >= 0 {
            # In-place conversion of an already-bound varname slot (the runtime
            # effect of the prologue MAKE_CELLs): boundness carries over.
            fast[fast_index] = PyCell(t="cell", val=fast[fast_index], filled=assigned[fast_index]);
        } else {
            newcell = PyCell(t="cell", val=py_none());
            fast.append(newcell);
        }
        ci = ci + 1;
    }
    fi = 0;
    while fi < len(closure) {
        fast.append(closure[fi] as PyObj);
        fi = fi + 1;
    }
    # The bound-tracking flags cover the FULL merged localsplus (a cell-targeted
    # comprehension's tail STORE_FAST restore addresses appended slots too).
    while len(assigned) < len(fast) {
        assigned.append(False);
    }
    frame = PyFrame(
        t="frame",
        co=co,
        fast=fast,
        assigned=assigned,
        closure=closure,
        stack=[],
        globals=globals,
        locals=locals,
        ip=0,
    );
    # A generator-flagged code object does not run on call: it returns a
    # generator wrapping the (unstarted) frame; execution begins on first resume.
    # CO_COROUTINE (0x80) is the async-def analogue -- the same suspendable frame,
    # tagged "coroutine" so type(coro).__name__ and the await/SEND driver treat it
    # as an awaitable (not a for-iterable) while reusing gen_resume/send_into.
    if (co.flags & 128) != 0 {
        return PyGenerator(t="coroutine", frame=frame, started=False, finished=False);
    }
    # CO_ASYNC_GENERATOR (0x200): `async def` with `yield`. Calling it creates a
    # LAZY async generator -- no frame execution until __anext__/asend/athrow/
    # aclose drive it through the agen_* awaitables (genobject.c
    # PyAsyncGenObject_New with an unstarted frame).
    if (co.flags & 512) != 0 {
        return PyGenerator(t="async_generator", frame=frame, started=False, finished=False);
    }
    if (co.flags & 32) != 0 {
        return PyGenerator(t="generator", frame=frame, started=False, finished=False);
    }
    return run_frame(frame);
}

# Innermost guest frame's globals, published by the run_frame wrapper so
# native paths can read the CURRENT frame the way CPython internals do
# (type_new derives cls.__module__ from the invoking frame's globals).
# One-slot holder rather than a bare `glob` -- a glob rebound inside a
# function is scoped local and never persists (see layer3_flag note); index
# assignment mutates the holder in place. An EMPTY dict in slot 0 means no
# guest frame is executing.
glob jac_frame_globals_slot: list[dict[str, PyObj]] = [{}];

# The defining-context module name for native class creation, or None when no
# executing guest frame carries one.
def jac_current_module_name -> PyObj | None {
    g = jac_frame_globals_slot[0];
    if "__name__" in g {
        nm = g["__name__"];
        if isinstance(nm, PyStr) {
            return nm;
        }
    }
    return None;
}

def run_frame(frame: PyFrame) -> PyObj {
    # Publish this frame's globals for the duration of its execution;
    # save/restore keeps recursion and generator resumes correct.
    outer_globals = jac_frame_globals_slot[0];
    jac_frame_globals_slot[0] = frame.globals;
    # Publish the live frame chain (innermost last) for sys._getframe and
    # f_back; suspended generator frames are off the chain while suspended,
    # matching CPython.
    jac_frame_chain_slot_ref().append(frame);
    try {
        return run_frame_inner(frame);
    } finally {
        jac_frame_chain_slot_ref().pop();
        jac_frame_globals_slot[0] = outer_globals;
    }
}

# Apply ceval_opcodes_containers outcome: (-1, _) ok; (>=0, _) jump ip; (-2, err) return.
def apply_opcode_outcome(out: tuple[int, PyObj]) -> tuple[bool, int, PyObj] {
    if out[0] >= 0 {
        return (True, out[0], py_none());
    }
    if out[0] == -2 {
        return (False, -1, out[1]);
    }
    return (True, -1, py_none());
}

def run_frame_inner(frame: PyFrame) -> PyObj {
    co = frame.co;
    fast = frame.fast;
    assigned = frame.assigned;
    closure = frame.closure;
    stack = frame.stack;
    globals = frame.globals;
    locals = frame.locals;
    code = co.co_code;
    ip = frame.ip;
    ext_arg = 0;
    # The stack of exceptions currently being handled (one entry per active except
    # block). A bare `raise` re-raises the top; PUSH_EXCEPT_INFO pushes on handler
    # entry, POP_EXCEPT pops on handler exit. A generator suspended inside an
    # except block carries the stack across the yield via frame.exc_state, so a
    # bare raise after resuming still names the exception being handled.
    exc_handling: list[PyObj] = [];
    if frame.exc_state is not None {
        exc_handling = frame.exc_state as list[PyObj];
        _handled_stack_append_each(exc_handling);
    }
    # Polymorphic opcode scratch slots: handlers below store PyObj values (and
    # occasionally the narrower PyStr/PyException subtypes) here, so they are
    # declared once up front instead of being pinned to a first-use type.
    result: PyObj = py_none();
    exc: PyObj = py_none();
    while ip < len(code) {
        offset = ip;
        op = code[ip];
        arg = code[ip + 1];
        ip = ip + 2 + 2 * opcode_cache_count(op);
        # EXTENDED_ARG carries the high bits of the FOLLOWING instruction's oparg
        # (up to four may chain). Fold any accumulated prefix into this arg, then
        # either stash it (this op IS the prefix) or clear it for the real op.
        arg = arg | (ext_arg << 8);
        ext_arg = 0;
        if op == OP_EXTENDED_ARG {
            ext_arg = arg;
            continue;
        }
        if op == OP_CACHE or op == OP_NOT_TAKEN or op == OP_NOP or op == OP_RESUME {
            continue;
        }
        if op == OP_LOAD_CONST {
            stack.append(co.consts[arg]);
            continue;
        }
        if op == OP_LOAD_SMALL_INT {
            # oparg is an unsigned int in [0, 256); it is ALWAYS non-negative
            # (CPython emits LOAD_CONST for negative literals). Do NOT sign-extend
            # -- doing so mis-decoded 128..255 as negatives.
            stack.append(PyInt(t="int", val=arg));
            continue;
        }
        if op == OP_LOAD_FAST or op == OP_LOAD_FAST_BORROW {
            fast_result = fast_value(co, arg, fast);
            if is_error(fast_result) {
                return fast_result;
            }
            stack.append(fast_result);
            continue;
        }
        if op == OP_LOAD_FAST_CHECK {
            fast_result = fast_value_check(co, arg, fast, assigned);
            if is_error(fast_result) {
                return fast_result;
            }
            stack.append(fast_result);
            continue;
        }
        if op == OP_STORE_FAST {
            if arg < len(fast) {
                fast[arg] = stack.pop();
                assigned[arg] = True;
                continue;
            }
            return py_error("UnboundLocalError", "invalid local variable");
        }
        if op == OP_DELETE_FAST {
            # `del local`: unbind the fast slot. A later LOAD_FAST raises
            # UnboundLocalError (the assigned flag gates that).
            if arg < len(fast) {
                fast[arg] = py_none();
                assigned[arg] = False;
                continue;
            }
            return py_error("UnboundLocalError", "invalid local variable");
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
            continue;
        }
        if op == OP_STORE_FAST_LOAD_FAST {
            store_index = arg // 16;
            load_index = arg % 16;
            if store_index >= len(fast) {
                return py_error("UnboundLocalError", "invalid local variable");
            }
            fast[store_index] = stack.pop();
            assigned[store_index] = True;
            load_result = fast_value(co, load_index, fast);
            if is_error(load_result) {
                return load_result;
            }
            stack.append(load_result);
            continue;
        }
        if op == OP_STORE_FAST_STORE_FAST {
            # Packed two-register store: TOS -> reg(arg>>4), TOS1 -> reg(arg&15).
            first_index = arg // 16;
            second_index = arg % 16;
            if first_index >= len(fast) or second_index >= len(fast) {
                return py_error("UnboundLocalError", "invalid local variable");
            }
            fast[first_index] = stack.pop();
            assigned[first_index] = True;
            fast[second_index] = stack.pop();
            assigned[second_index] = True;
            continue;
        }
        if op == OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW or op == OP_LOAD_FAST_LOAD_FAST {
            first = arg // 16;
            second = arg % 16;
            first_result = fast_value(co, first, fast);
            second_result = fast_value(co, second, fast);
            if is_error(first_result) {
                return first_result;
            }
            if is_error(second_result) {
                return second_result;
            }
            stack.append(first_result);
            stack.append(second_result);
            continue;
        }
        if op == OP_LOAD_GLOBAL {
            name_index = arg // 2;
            if name_index >= len(co.names) {
                return py_error("NameError", "invalid global name");
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
                    ip = target;
                    continue;
                }
                return value;
            }
            stack.append(value);
            if (arg & 1) != 0 {
                stack.append(py_none());
            }
            continue;
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
                    ip = target;
                    continue;
                }
                return value;
            }
            stack.append(value);
            continue;
        }
        if op == OP_LOAD_DEREF {
            cell = resolve_cell(fast, arg);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            # An empty cell is distinct from a None binding: emptiness lives on
            # the shared cell object (CPython's cell-NULL check), not the slot.
            if not cell.filled {
                err = format_exc_unbound(co, arg);
                target = recover_exception(co, err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return err;
            }
            stack.append(cell.val);
            continue;
        }
        if op == OP_LOAD_CLOSURE {
            cell = resolve_cell(fast, arg);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            stack.append(cell);
            continue;
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
                            ip = target;
                            continue;
                        }
                        return got;
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
                        ip = target;
                        continue;
                    }
                    return err;
                }
                value = cell.val;
            }
            stack.append(value);
            continue;
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
                            ip = target;
                            continue;
                        }
                        return got;
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
                            ip = target;
                            continue;
                        }
                        return value;
                    }
                }
            }
            stack.append(value);
            continue;
        }
        if op == OP_STORE_DEREF {
            value = stack.pop();
            cell = resolve_cell(fast, arg);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            cell.val = value;
            cell.filled = True;
            continue;
        }
        if op == OP_DELETE_DEREF {
            # CPython TARGET(DELETE_DEREF): unset the shared cell so later
            # LOAD_DEREFs see the exact unbound error; deleting an already
            # empty cell is the same unbound error, not a silent no-op.
            cell = resolve_cell(fast, arg);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            if not cell.filled {
                err = format_exc_unbound(co, arg);
                target = recover_exception(co, err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return err;
            }
            cell.val = py_none();
            cell.filled = False;
            continue;
        }
        if op == OP_MAKE_CELL {
            # Dynamic slot conversion (CPython _PyFrame_MakeAndSetCell): wrap
            # the slot's current value in a fresh cell. Subsequent *_DEREF ops
            # and closure captures go through that cell while plain *_FAST ops
            # keep addressing the slot wholesale -- which is also how a tail
            # STORE_FAST un-converts it after an inlined comprehension. Each
            # comprehension execution mints a NEW cell per loop var, so lambda
            # sets captured by earlier comprehensions keep their own cells.
            # Idempotent on already-converted slots (prologue MAKE_CELLs).
            if arg < len(fast) and not isinstance(fast[arg], PyCell) {
                # A None slot is the VM's unset placeholder (LOAD_FAST_AND_CLEAR
                # nulls the slot before comprehension conversions); anything else
                # was genuinely bound and stays readable through the cell.
                fast[arg] = PyCell(
                    t="cell",
                    val=fast[arg],
                    filled=(not isinstance(fast[arg], PyNoneType)),
                );
            }
            continue;
        }
        if op == OP_COPY_FREE_VARS {
            # No-op: frame setup already placed the closure cells in the
            # appended freevar region of the merged localsplus.
            continue;
        }
        if op == OP_LOAD_LOCALS {
            stack.append(dict_from_str_map(locals));
            continue;
        }
        if op == OP_SETUP_ANNOTATIONS {
            # CPython SETUP_ANNOTATIONS: bind an empty __annotations__ dict in
            # the frame namespace when absent (module/class annotation setup).
            if "__annotations__" not in locals {
                locals["__annotations__"] = PyDict(t="dict", items={});
            }
            continue;
        }
        if op == OP_STORE_NAME {
            locals[co.names[arg]] = stack.pop();
            continue;
        }
        if op == OP_STORE_GLOBAL {
            # `global x; x = ...` inside a function -- write straight to the
            # module globals, bypassing the frame's fast/locals.
            globals[co.names[arg]] = stack.pop();
            continue;
        }
        if op == OP_DELETE_GLOBAL {
            gdel_name = co.names[arg];
            if gdel_name in globals {
                del globals[gdel_name];
                continue;
            }
            gdeleted = py_error("NameError", "name '" + gdel_name + "' is not defined");
            target = recover_exception(co, gdeleted, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return gdeleted;
        }
        if op == OP_DELETE_NAME {
            del_name = co.names[arg];
            if del_name in locals {
                del locals[del_name];
                continue;
            }
            deleted = py_error("NameError", "name '" + del_name + "' is not defined");
            target = recover_exception(co, deleted, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return deleted;
        }
        if op == OP_LOAD_BUILD_CLASS {
            stack.append(PyBuildClass(t="build_class"));
            continue;
        }
        if op == OP_MAKE_FUNCTION {
            function = make_function_from_stack(stack, globals);
            if is_error(function) {
                return function;
            }
            stack.append(function);
            continue;
        }
        if op == OP_SET_FUNCTION_ATTRIBUTE {
            function = stack.pop() as PyFunction;
            attribute = stack.pop();
            if arg == 1 and attribute.t == "tuple" {
                function.defaults = tuple_value(attribute);
            } elif arg == 2 and attribute.t == "dict" {
                function.kwdefaults = (attribute as PyDict).dict_str_map();
            } elif arg == 8 and attribute.t == "tuple" {
                # Closure seeding: elements are already live cells (captured via
                # LOAD_FAST_BORROW/LOAD_CLOSURE on converted localsplus slots);
                # any raw value gets boxed in a fresh cell.
                function.closure = [];
                for item in tuple_value(attribute) {
                    if item.t == "cell" {
                        function.closure.append(item as PyCell);
                    } else {
                        function.closure.append(PyCell(t="cell", val=item, filled=True));
                    }
                }
            }
            stack.append(function);
            continue;
        }
        if op == OP_BUILD_LIST {
            oc_out = op_build_list(stack, arg);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_BUILD_TUPLE {
            values: list[PyObj] = [];
            while len(values) < arg {
                values.insert(0, stack.pop());
            }
            stack.append(PyTuple(t="tuple", items=values));
            continue;
        }
        if op == OP_BUILD_INTERPOLATION {
            # PEP 750 t-strings. Stack at entry (CPython compile.c):
            #   [literals_tuple, value, expr_source, (format_spec)]
            # oparg: bit0 = format spec present; bits 3+ = conversion id
            # (0 None, 1 r, 2 s, 3 a). The literals tuple stays put for
            # BUILD_TEMPLATE.
            fmt: PyObj = py_none();
            if (arg & 1) != 0 {
                fmt = stack.pop();
            }
            expr = stack.pop();
            value_i = stack.pop();
            conv_id = (arg >> 3) & 3;
            conv: PyObj = py_none();
            if conv_id == 1 {
                conv = PyStr(t="str", val="r");
            } elif conv_id == 2 {
                conv = PyStr(t="str", val="s");
            } elif conv_id == 3 {
                conv = PyStr(t="str", val="a");
            }
            stack.append(make_interpolation(value_i, expect_str(expr), conv, fmt));
            continue;
        }
        if op == OP_BUILD_TEMPLATE {
            # Stack: [literals_tuple, parts_tuple] -- Template(strings,
            # interpolations).
            tmpl_parts = stack.pop();
            tmpl_lits = stack.pop();
            stack.append(make_template(tmpl_lits as PyTuple, tmpl_parts as PyTuple));
            continue;
        }
        if op == OP_BUILD_MAP {
            oc_out = op_build_map(stack, arg, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_BUILD_SET {
            oc_out = op_build_set(stack, arg, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_SET_UPDATE {
            oc_out = op_set_update(stack, arg, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_CONVERT_VALUE {
            value = stack.pop();
            if isinstance(value, PyException) {
                exc = value as PyException;
                if arg == 2 {
                    result = baseexception_repr(exc, py_repr);
                } elif arg == 3 {
                    # CONVERT_VALUE oparg 3 is ascii() (1=str, 2=repr, 3=ascii
                    # in CPython 3.14 bytecode). The non-ASCII escaping half
                    # of ascii() stays host-only, so delegate -- the caught
                    # exception marshals to a REAL host instance
                    # (to_host -> host_exception), keeping repr content and
                    # byte-exact escaping. Treating 3 as a str form here made
                    # f"{e!a}" print the plain message (5967ea874 regression).
                    result = host_convert(value, 3);
                } else {
                    # Host-RAISED exceptions carry their live HOST instance in
                    # `raw` (a PyHostProxy): its host str is byte-exact by
                    # construction and beats any native reconstruction from
                    # (possibly lossy) args. Guest user-exception instances
                    # also keep their instance in `raw` (a PyUserObj) but the
                    # native per-type dispatch is authoritative there -- the
                    # host-side mirror class has no builtin __str__ ancestry.
                    if exc.raw is not None and isinstance(exc.raw, PyHostProxy) {
                        result = host_convert(exc.raw as PyObj, 1);
                    } else {
                        # str-form conversion stays native so the per-type __str__
                        # overrides (OSError smart forms, KeyError repr-form,
                        # SyntaxError suffixes) apply to natively constructed
                        # instances instead of a lossy host reconstruction.
                        result = baseexception_str(exc, py_repr, py_str);
                    }
                }
            } else {
                result = host_convert(value, arg);
            }
            if is_error(result) {
                # A guest __format__/__str__/__repr__ raising during conversion
                # must dispatch to a same-frame handler.
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_FORMAT_SIMPLE {
            value = stack.pop();
            result = host_format(value, "");
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_FORMAT_WITH_SPEC {
            spec = stack.pop();
            value = stack.pop();
            result = host_format(value, expect_str(spec));
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BUILD_STRING {
            str_parts: list[PyObj] = [];
            while len(str_parts) < arg {
                str_parts.insert(0, stack.pop());
            }
            joined = "";
            for part in str_parts {
                joined = joined + expect_str(part);
            }
            stack.append(PyStr(t="str", val=joined));
            continue;
        }
        if op == OP_LIST_EXTEND {
            oc_out = op_list_extend(stack, arg, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_LIST_APPEND {
            oc_out = op_list_append(stack, arg);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_SET_ADD {
            oc_out = op_set_add(stack, arg);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_MAP_ADD {
            oc_out = op_map_add(stack, arg);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_DICT_UPDATE {
            oc_out = op_dict_update(stack, arg, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_DICT_MERGE {
            oc_out = op_dict_merge(stack, arg, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_UNPACK_SEQUENCE {
            seq = stack.pop();
            # CPython honors a __len__ hint BEFORE iterating: exact-length
            # mismatches raise immediately with the got-count in the message,
            # and old-style __getitem__ iterables whose len disagrees with
            # their IndexError termination never hang the drain loop.
            # ITERATORS are excluded: their __len__ (when present) reflects
            # total capacity, not remaining items, and host omits got-count
            # for them entirely (ex38: '(expected 3)' with no got).
            use_hint = not PyIter_Check(seq);
            hint = py_none();
            if use_hint {
                hint = py_len(seq);
            }
            if not is_error(hint) and isinstance(hint, PyInt) {
                lv = (hint as PyInt).val;
                if lv < arg {
                    unpack_hint_err = py_error(
                        "ValueError",
                        "not enough values to unpack (expected "
                            + str(arg) + ", got " + str(lv) + ")",
                    );
                    target = recover_exception(co, unpack_hint_err, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return unpack_hint_err;
                }
                if lv > arg {
                    unpack_hint_err2 = py_error(
                        "ValueError",
                        "too many values to unpack (expected "
                            + str(arg) + ", got " + str(lv) + ")",
                    );
                    target = recover_exception(co, unpack_hint_err2, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return unpack_hint_err2;
                }
            }
            it = py_iter(seq);
            if is_error(it) {
                # CPython's UNPACK_SEQUENCE handler catches the TypeError from
                # GetIter and reformats it with unpack-specific wording
                # ("cannot unpack non-iterable int object"); mirror that so
                # the message names the operand type instead of arriving empty.
                if (it as PyError).exception.type_name == "TypeError" {
                    it = py_error(
                        "TypeError",
                        "cannot unpack non-iterable " + seq.tp_type_name() + " object",
                    );
                }
                target = recover_exception(co, it, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return it;
            }
            # Uniform drain across every iterator shape send_into serves
            # (materialized iters, generators/coroutines, calliter/seqiter/
            # rangeiter): the old shape-dispatch silently produced an empty
            # unpack for rangeiter/seqiter/calliter.
            unpacked: list[PyObj] = [];
            drain_failed = False;
            while True {
                nxt = send_into(it, py_none());
                if is_error(nxt) {
                    # Drain error (guest raise inside the iterator) must
                    # dispatch to a same-frame handler.
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                        drain_failed = True;
                    } else {
                        return nxt;
                    }
                    break;
                }
                if nxt.t == "genstop" {
                    break;
                }
                unpacked.append(nxt);
                if len(unpacked) > arg {
                    # CPython stops consuming the moment one extra item
                    # appears -- the iterator stays positioned for later
                    # next() calls (doctests rely on this). Draining to
                    # exhaustion first would strand the caller.
                    # NOTE: must set drain_failed + BREAK (mirroring the
                    # send_into-error path above); a bare `continue` here
                    # would re-enter THIS drain loop instead of dispatching
                    # to the exception handler.
                    unpack_err = py_error(
                        "ValueError",
                        "too many values to unpack (expected " + str(arg) + ")",
                    );
                    target = recover_exception(co, unpack_err, offset, stack);
                    if target >= 0 {
                        ip = target;
                        drain_failed = True;
                    } else {
                        return unpack_err;
                    }
                    break;
                }
            }
            if drain_failed {
                continue;
            }
            unpack_err: PyObj = py_none();
            if len(unpacked) < arg {
                unpack_err = py_error(
                    "ValueError",
                    "not enough values to unpack (expected "
                        + str(arg)
                        + ", got "
                        + str(len(unpacked))
                        + ")",
                );
            } elif len(unpacked) > arg {
                unpack_err = py_error(
                    "ValueError",
                    "too many values to unpack (expected " + str(arg) + ")",
                );
            }
            if is_error(unpack_err) {
                target = recover_exception(co, unpack_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return unpack_err;
            }
            # Push in reverse so the first element lands on top of the stack for
            # the successive STORE ops (CPython's UNPACK_SEQUENCE ordering).
            uk = arg - 1;
            while uk >= 0 {
                stack.append(unpacked[uk]);
                uk = uk - 1;
            }
            continue;
        }
        if op == OP_UNPACK_EX {
            # oparg = before | (after << 8); a starred target captures the middle.
            before = arg % 256;
            after = arg // 256;
            seq = stack.pop();
            it = py_iter(seq);
            if is_error(it) {
                # Same TypeError reformat as UNPACK_SEQUENCE above.
                if (it as PyError).exception.type_name == "TypeError" {
                    it = py_error(
                        "TypeError",
                        "cannot unpack non-iterable " + seq.tp_type_name() + " object",
                    );
                }
                target = recover_exception(co, it, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return it;
            }
            # Uniform drain across every iterator shape send_into serves
            # (materialized iters, generators/coroutines, calliter/seqiter/
            # rangeiter): the old shape-dispatch silently produced an empty
            # unpack for rangeiter/seqiter/calliter.
            unpack_ex_items: list[PyObj] = [];
            drain_failed = False;
            while True {
                nxt = send_into(it, py_none());
                if is_error(nxt) {
                    # Same-frame dispatch for the drain error.
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                        drain_failed = True;
                    } else {
                        return nxt;
                    }
                    break;
                }
                if nxt.t == "genstop" {
                    break;
                }
                unpack_ex_items.append(nxt);
            }
            if drain_failed {
                continue;
            }
            m = len(unpack_ex_items);
            if m < before + after {
                ex_err = py_error(
                    "ValueError",
                    "not enough values to unpack (expected at least "
                        + str(before + after)
                        + ", got "
                        + str(m)
                        + ")",
                );
                target = recover_exception(co, ex_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return ex_err;
            }
            # Stack top->bottom must be: head[0..before-1], middle-list,
            # tail[m-after..m-1]. Push tail deepest-first, then middle, then head.
            j = m - 1;
            while j >= m - after {
                stack.append(unpack_ex_items[j]);
                j = j - 1;
            }
            middle_items: list[PyObj] = [];
            mk = before;
            while mk < m - after {
                middle_items.append(unpack_ex_items[mk]);
                mk = mk + 1;
            }
            stack.append(PyList(t="list", items=middle_items));
            b = before - 1;
            while b >= 0 {
                stack.append(unpack_ex_items[b]);
                b = b - 1;
            }
            continue;
        }
        if op == OP_GET_LEN {
            len_obj = stack[len(stack) - 1];
            len_res = py_len(len_obj);
            if is_error(len_res) {
                target = recover_exception(co, len_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return len_res;
            }
            stack.append(len_res);
            continue;
        }
        if op == OP_MATCH_SEQUENCE {
            seq_subject = stack[len(stack) - 1];
            stack.append(PyBool(t="bool", val=py_type_has_sequence_flag(seq_subject)));
            continue;
        }
        if op == OP_MATCH_MAPPING {
            map_subject = stack[len(stack) - 1];
            stack.append(PyBool(t="bool", val=py_type_has_mapping_flag(map_subject)));
            continue;
        }
        if op == OP_MATCH_KEYS {
            mk_keys = stack[len(stack) - 1];
            mk_subject = stack[len(stack) - 2];
            mk_res = py_match_keys(mk_subject, mk_keys);
            if is_error(mk_res) {
                target = recover_exception(co, mk_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return mk_res;
            }
            stack.append(mk_res);
            continue;
        }
        if op == OP_MATCH_CLASS {
            mc_names = stack.pop();
            mc_type = stack.pop();
            mc_subject = stack.pop();
            mc_res = py_match_class(mc_subject, mc_type, arg, mc_names);
            if is_error(mc_res) {
                target = recover_exception(co, mc_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return mc_res;
            }
            stack.append(mc_res);
            continue;
        }
        if op == OP_GET_ITER {
            iterable = py_iter(stack.pop());
            if is_error(iterable) {
                target = recover_exception(co, iterable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return iterable;
            }
            stack.append(iterable);
            continue;
        }
        if op == OP_GET_YIELD_FROM_ITER {
            # `yield from`: a generator (or coroutine) is already its own
            # iterator and is left in place so send()/throw() reach it directly;
            # anything else is turned into an iterator like GET_ITER.
            top = stack[len(stack) - 1];
            if top.t == "generator" {
                continue;
            }
            iterable = py_iter(stack.pop());
            if is_error(iterable) {
                target = recover_exception(co, iterable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return iterable;
            }
            stack.append(iterable);
            continue;
        }
        if op == OP_GET_AWAITABLE {
            # `await x`: resolve x to the iterator the following SEND loop drives.
            top = stack[len(stack) - 1];
            awaitable = py_get_awaitable(top);
            if is_error(awaitable) {
                target = recover_exception(co, awaitable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return awaitable;
            }
            stack[len(stack) - 1] = awaitable;
            continue;
        }
        if op == OP_GET_AITER {
            iterable = stack.pop();
            aiter = py_aiter(iterable);
            if is_error(aiter) {
                target = recover_exception(co, aiter, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return aiter;
            }
            stack.append(aiter);
            continue;
        }
        if op == OP_GET_ANEXT {
            aiter = stack[len(stack) - 1];
            awaitable = py_anext(aiter);
            if is_error(awaitable) {
                target = recover_exception(co, awaitable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return awaitable;
            }
            stack.append(awaitable);
            continue;
        }
        if op == OP_END_ASYNC_FOR {
            # Async-for cleanup: [..., aiter, exc]. StopAsyncIteration ends the
            # loop (pop both, jump past the body); anything else re-raises.
            exc = stack.pop();
            stack.pop();
            exc_name = "";
            if exc.t == "exception" {
                exc_name = (exc as PyException).type_name;
            }
            if exc_name == "StopAsyncIteration" {
                continue;
            }
            reraised = py_raise_value(exc);
            # This is a RERAISE-class event (the error entry for main was
            # already appended when the awaited __anext__ failed): growing the
            # traceback here duplicated main's frame (main|main|agen vs host
            # main|agen). Route through dispatch like every other reraise.
            target = dispatch_exception(co, reraised, offset, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return reraised;
        }
        if op == OP_SEND {
            # yield-from step. Stack: [..., receiver, sent]. Drive the receiver
            # one step; on a yield replace `sent` with the yielded value and fall
            # through to YIELD_VALUE (re-suspending the outer generator); on
            # exhaustion replace `sent` with the sub-iterator's return value and
            # jump past the loop to END_SEND.
            sent = stack[len(stack) - 1];
            receiver = stack[len(stack) - 2];
            if frame.pending_throw is not None {
                thrown_err = frame.pending_throw as PyObj;
                frame.pending_throw = None;
                step = send_throw_into(receiver, thrown_err);
            } else {
                step = send_into(receiver, sent);
            }
            if is_error(step) {
                target = recover_exception(co, step, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return step;
            }
            if step.t == "genstop" {
                stack[len(stack) - 1] = (step as PyGenStop).val;
                ip = ip + 2 * arg;
            } else {
                stack[len(stack) - 1] = step;
            }
            continue;
        }
        if op == OP_END_SEND {
            # (receiver, value -- value): drop the exhausted sub-iterator, keep
            # its return value as the yield-from expression result.
            value = stack.pop();
            stack.pop();
            stack.append(value);
            continue;
        }
        if op == OP_CLEANUP_THROW {
            # Reached when an exception thrown into a yield-from lands here. Stack:
            # [sub_iter, last_sent, exc]. A StopIteration means the sub-iterator
            # finished handling the throw: unwind to (None, value) and loop to
            # END_SEND. Any other exception re-raises out of the outer generator.
            exc = stack.pop();
            stack.pop();
            stack.pop();
            exc_name = "";
            if exc.t == "exception" {
                exc_name = (exc as PyException).type_name;
            }
            # A StopIteration (or subclass) means the sub-iterator finished
            # handling the throw: unwind to (None, value) and loop to END_SEND.
            if exc_name == "StopIteration"
                or ((exc as PyException).family != ""
                and exc_name_matches((exc as PyException).family, "StopIteration")) {
                payload = py_none();
                if (exc as PyException).value is not None {
                    payload = (exc as PyException).value as PyObj;
                }
                stack.append(py_none());
                stack.append(payload);
                continue;
            }
            # Non-StopIteration: re-dispatch the exception out of the yield-from
            # (CPython CLEANUP_THROW -> exit_unwind). A re-dispatch is not an
            # error event, so no traceback entry is added here -- the entry for
            # this frame was already laid down at the failing SEND/error site;
            # grow-free handler search keeps the cadence at one per frame.
            reraised = py_raise_value(exc);
            target = dispatch_exception(co, reraised, offset, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return reraised;
        }
        if op == OP_FOR_ITER {
            top = stack[len(stack) - 1];
            if top.t == "dictiter" {
                di = top as PyDictIter;
                if di.dictiter_stale() {
                    nxt = dictiter_error();
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                    } else {
                        return nxt;
                    }
                } elif di.index < len(di.keys) {
                    stack.append(dictiter_yield(di));
                    di.index = di.index + 1;
                } else {
                    stack.pop();
                    ip = ip + 2 * arg;
                }
                continue;
            }
            if top.t == "generator" {
                nxt = gen_resume(top as PyGenerator, py_none());
                if nxt.t == "genstop" {
                    stack.pop();
                    ip = ip + 2 * arg;
                } elif is_error(nxt) {
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                    } else {
                        return nxt;
                    }
                } else {
                    stack.append(nxt);
                }
                continue;
            }
            if top.t == "rangeiter" {
                nxt = send_into(top, py_none());
                if nxt.t == "genstop" {
                    stack.pop();
                    ip = ip + 2 * arg;
                } elif is_error(nxt) {
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                    } else {
                        return nxt;
                    }
                } else {
                    stack.append(nxt);
                }
                continue;
            }
            if top.t == "calliter" {
                nxt = calliter_next(top as PyCallableIter);
                if nxt.t == "genstop" {
                    stack.pop();
                    ip = ip + 2 * arg;
                } elif is_error(nxt) {
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                    } else {
                        return nxt;
                    }
                } else {
                    stack.append(nxt);
                }
                continue;
            }
            if top.t == "seqiter" {
                nxt = seqiter_next(top as PySeqIter);
                if nxt.t == "genstop" {
                    stack.pop();
                    ip = ip + 2 * arg;
                } elif is_error(nxt) {
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                    } else {
                        return nxt;
                    }
                } else {
                    stack.append(nxt);
                }
                continue;
            }
            if isinstance(top, PyUserObj)
                and user_has_dunder(top as PyUserObj, "__next__") {
                # User-defined iterator (class-iterator idiom): FOR_ITER drives
                # tp_iternext == guest __next__; StopIteration pops the loop.
                nxt = call_user_dunder(top as PyUserObj, "__next__", []);
                if is_error(nxt) {
                    # tp_iternext contract: StopIteration OR ANY SUBCLASS ends
                    # the loop (matched by type, not exact name); anything else
                    # propagates through handler dispatch.
                    if error_is_stopiteration(nxt) {
                        stack.pop();
                        ip = ip + 2 * arg;
                    } else {
                        target = recover_exception(co, nxt, offset, stack);
                        if target >= 0 {
                            ip = target;
                        } else {
                            return nxt;
                        }
                    }
                } else {
                    stack.append(nxt);
                }
                continue;
            }
            # Generic tail: drive ANY remaining iterator shape through
            # send_into (native iters, dict/range iterators, user objects whose
            # __next__ only resolves through the full attribute path). The old
            # unconditional PyIter downcast VM-crashed on those user shapes.
            nxt = send_into(top, py_none());
            if nxt.t == "genstop" {
                stack.pop();
                ip = ip + 2 * arg;
            } elif is_error(nxt) {
                target = recover_exception(co, nxt, offset, stack);
                if target >= 0 {
                    ip = target;
                } else {
                    return nxt;
                }
            } else {
                stack.append(nxt);
            }
            continue;
        }
        if op == OP_END_FOR or op == OP_POP_ITER {
            continue;
        }
        if op == OP_JUMP_FORWARD {
            ip = ip + 2 * arg;
            continue;
        }
        if op == OP_JUMP_BACKWARD or op == OP_JUMP_BACKWARD_NO_INTERRUPT {
            ip = ip - 2 * arg;
            continue;
        }
        if op == OP_POP_JUMP_IF_FALSE
            or op == OP_POP_JUMP_IF_TRUE
            or op == OP_POP_JUMP_IF_NONE
            or op == OP_POP_JUMP_IF_NOT_NONE {
            condition = stack.pop();
            jump = False;
            if op == OP_POP_JUMP_IF_FALSE or op == OP_POP_JUMP_IF_TRUE {
                # Implicit-truth slot with a real error channel: a raising
                # __bool__/__len__ propagates like CPython's PyObject_IsTrue.
                truth = py_slot_truth(condition);
                if is_error(truth) {
                    target = recover_exception(co, truth, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return truth;
                }
                jump = (truth as PyBool).val;
                if op == OP_POP_JUMP_IF_FALSE {
                    jump = not jump;
                }
            } elif op == OP_POP_JUMP_IF_NONE {
                jump = condition.t == "none";
            } else {
                jump = condition.t != "none";
            }
            if jump {
                ip = ip + 2 * arg;
            }
            continue;
        }
        if op == OP_COMPARE_OP {
            rhs = stack.pop();
            lhs = stack.pop();
            result = py_compare(arg >> 5, lhs, rhs);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_IS_OP {
            rhs = stack.pop();
            lhs = stack.pop();
            same = py_identity(lhs, rhs);
            if arg == 1 {
                same = not same;
            }
            stack.append(PyBool(t="bool", val=same));
            continue;
        }
        if op == OP_UNARY_NOT {
            operand = stack.pop();
            truth = py_slot_truth(operand);
            if is_error(truth) {
                target = recover_exception(co, truth, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return truth;
            }
            stack.append(PyBool(t="bool", val=not (truth as PyBool).val));
            continue;
        }
        if op == OP_UNARY_NEGATIVE {
            result = py_negative(stack.pop());
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_UNARY_INVERT {
            result = py_invert(stack.pop());
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BINARY_OP {
            if arg == 26 {
            oc_out = op_binary_subscript(stack, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
            }
            rhs = stack.pop();
            lhs = stack.pop();
            result = py_binop(arg, lhs, rhs);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BINARY_SLICE {
            oc_out = op_binary_slice(stack, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_BUILD_SLICE {
            # oparg is 2 (start:stop) or 3 (start:stop:step); operands on stack.
            slice_step: PyObj = py_none();
            if arg == 3 {
                slice_step = stack.pop();
            }
            slice_stop = stack.pop();
            slice_start = stack.pop();
            stack.append(
                PySlice(t="slice", start=slice_start, stop=slice_stop, step=slice_step)
            );
            continue;
        }
        if op == OP_LOAD_ATTR {
            owner = stack.pop();
            name = co.names[arg // 2];
            result = py_attr(owner, name);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            if (arg & 1) != 0 {
                stack.append(result);
                stack.append(py_none());
            } else {
                stack.append(result);
            }
            continue;
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
                    ip = target;
                    continue;
                }
                return result;
            }
            # CPython super_getattro applies the descriptor protocol to what
            # the MRO walk found: a property getter fires against the live
            # instance, a function binds to it, a classmethod binds its class.
            super_bound = descriptor_get(result, super_self, super_self);
            if (arg & 1) != 0 {
                stack.append(super_bound);
                stack.append(py_none());
            } else {
                stack.append(super_bound);
            }
            continue;
        }
        if op == OP_STORE_ATTR {
            owner = stack.pop();
            field = stack.pop();
            result = py_set_attr(owner, co.names[arg], field);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            continue;
        }
        if op == OP_DELETE_ATTR {
            owner = stack.pop();
            result = py_del_attr(owner, co.names[arg]);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            continue;
        }
        if op == OP_STORE_SLICE {
            oc_out = op_store_slice(stack, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_STORE_SUBSCR {
            oc_out = op_store_subscr(stack, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
        if op == OP_DELETE_SUBSCR {
            oc_out = op_delete_subscr(stack, co, offset);
            oc_apply = apply_opcode_outcome(oc_out);
            if not oc_apply[0] {
                return oc_apply[2];
            }
            if oc_apply[1] >= 0 {
                ip = oc_apply[1];
            }
            continue;
        }
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
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_IMPORT_FROM {
            module = stack[len(stack) - 1];
            result = py_attr(module, co.names[arg]);
            if is_error(result) {
                # CPython's import_from converts a bare AttributeError into
                # "ImportError: cannot import name 'x' from 'mod' (__file__)"
                # -- every other error propagates unchanged.
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
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_PUSH_NULL {
            stack.append(py_none());
            continue;
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
                return py_error("RuntimeError", "CALL stack underflow");
            }
            self_or_null = stack.pop();
            if len(stack) == 0 {
                return py_error("RuntimeError", "CALL stack underflow");
            }
            fn = stack.pop();
            # globals() binds to THIS frame's namespace (a live view), which only
            # the ceval holds -- resolve it here rather than in PyNativeBuiltin.
            if fn.t == "native_builtin" and (fn as PyNativeBuiltin).name == "globals" {
                stack.append(PyGlobalsProxy(t="globals", ns=globals));
                continue;
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
                for loc_key in locals {
                    local_names[loc_key] = True;
                }
                si = 0;
                while si < len(fast) {
                    slot_bound = False;
                    if isinstance(fast[si], PyCell) {
                        if ((fast[si] as PyCell).filled) {
                            slot_bound = True;
                        }
                    } elif si < len(assigned) and assigned[si] {
                        slot_bound = True;
                    }
                    if slot_bound {
                        local_names[localsplus_name(co, si)] = True;
                    }
                    si = si + 1;
                }
                stack.append(py_dir_sorted(local_names));
                continue;
            }
            # exec() must run IN the VM against the LIVE namespace dicts -- see
            # builtin_exec below. Only this call site holds the running frame's
            # globals/locals for the one-argument form.
            if fn.t == "native_builtin" and (fn as PyNativeBuiltin).name == "exec" {
                result = builtin_exec(call_args, kwargs_for_call, globals, locals);
                if is_error(result) {
                    target = recover_exception(co, result, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return result;
                }
                stack.append(result);
                continue;
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
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
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
                    ip = target;
                    continue;
                }
                return ex_args_list;
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
                    return hkw_r[1] as PyObj;
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
                    ip = target;
                    continue;
                }
                return ex_result;
            }
            stack.append(ex_result);
            continue;
        }
        if op == OP_PUSH_EXC_INFO {
            if len(stack) > 0 {
                exception = stack.pop();
                stack.append(py_none());
                stack.append(exception);
                # Mark this exception as the one being handled (for bare `raise`).
                exc_handling.append(exception);
                _handled_exc_stack.append(exception);
            }
            continue;
        }
        if op == OP_CHECK_EG_MATCH {
            # except* matching -- CPython CHECK_EG_MATCH: validate the caught
            # class (_PyEval_CheckExceptStarTypeValid), then split the active
            # exception against it (_PyEval_ExceptionGroupMatch). The stack
            # becomes (rest, match) with match on top; None means "nothing
            # matched". Setting the matched group as the handled exception
            # (SetHandledException) belongs to the PREP_RERAISE_STAR lane.
            eg_target = stack.pop();
            eg_exc = stack.pop();
            invalid = eg_validate_star_target(eg_target);
            if not is_error(invalid) {
                pair = exception_group_split(eg_exc, eg_target);
                if is_error(pair[0]) {
                    invalid = pair[0];
                } else {
                    stack.append(pair[0]);
                    stack.append(pair[1]);
                    continue;
                }
            }
            target = recover_exception(co, invalid, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return invalid;
        }
        if op == OP_CHECK_EXC_MATCH {
            match_type: PyObj = stack.pop();
            exception = stack[len(stack) - 1];
            # CPython validates the target BEFORE matching; an invalid one is a
            # raising TypeError, not a non-match.
            if not except_target_valid(match_type) {
                exc_match_err = py_error(
                    "TypeError",
                    "catching classes that do not inherit from BaseException is not allowed"
                );
                target = recover_exception(co, exc_match_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return exc_match_err;
            }
            stack.append(
                PyBool(t="bool", val=exception_matches(exception, match_type))
            );
            continue;
        }
        if op == OP_POP_EXCEPT {
            if len(stack) > 0 {
                stack.pop();
            }
            if len(exc_handling) > 0 {
                exc_handling.pop();
            }
            if len(_handled_exc_stack) > 0 {
                _handled_exc_stack.pop();
            }
            continue;
        }
        if op == OP_RAISE_VARARGS {
            # arg: 0 = re-raise, 1 = raise exc, 2 = raise exc from cause. For the
            # `from` form the cause is on top, the exception below it.
            raised = py_none();
            raise_cause: PyObj = py_none();
            if arg == 2 {
                raise_cause = stack.pop();
                raised = stack.pop();
            } elif arg == 1 {
                raised = stack.pop();
            } elif len(exc_handling) > 0 {
                # Bare `raise`: re-raise the exception currently being handled.
                raised = exc_handling[len(exc_handling) - 1];
            }
            if arg == 0 and raised.t == "none" {
                # CPython bare `raise` outside any handler is RuntimeError
                # (PyErr_GetReraised), not the generic not-an-exception TypeError.
                result = py_error("RuntimeError", "No active exception to re-raise");
            } else {
                result = py_raise_value(raised);
            }
            # Implicit chaining (CPython PyErr_SetObject): raising while another
            # exception is being handled records the handled one as the new
            # exception's __context__ -- unless the raised object IS that
            # exception (bare re-raise keeps its existing chain) or a context
            # is already recorded. Applies to `raise X from Y` too: cause and
            # context are independent fields there.
            if len(exc_handling) > 0 {
                handled_exc = exc_handling[len(exc_handling) - 1];
                if (
                    isinstance(result, PyError)
                    and not (handled_exc is raised)
                    and (result as PyError).exception.context is None
                ) {
                    if handled_exc.t == "exception" {
                        (result as PyError).exception.context = (
                            handled_exc as PyException
                        );
                    } elif isinstance(handled_exc, PyUserObj) {
                        wrapped = py_raise_value(handled_exc);
                        if isinstance(wrapped, PyError) {
                            (result as PyError).exception.context = (
                                wrapped as PyError
                            ).exception;
                        }
                    }
                }
            }
            # `raise X from Y`: record Y on the raised exception so e.__cause__
            # reads it back. `from None` carries no cause object but still sets
            # __suppress_context__ (CPython PyErr_SetCause semantics).
            if arg == 2 and isinstance(result, PyError) {
                if raise_cause.t != "none" {
                    cause_err = py_raise_value(raise_cause);
                    if isinstance(cause_err, PyError) {
                        cause_exc = (cause_err as PyError).exception;
                        (result as PyError).exception.cause = cause_exc;
                        # PyErr_SetCause: a real cause implies __suppress_context__.
                        (result as PyError).exception.suppress_context = PyBool(
                            t="bool", val=True
                        );
                    }
                } else {
                    (result as PyError).exception.suppress_context = PyBool(
                        t="bool", val=True
                    );
                }
            }
            # Bare `raise` (arg == 0) re-dispatches an existing exception:
            # CPython routes RAISE_VARARGS 0 straight to exception_unwind, so
            # no new traceback entry (dispatch_exception). A fresh raise
            # (arg 1/2) or the RuntimeError fallback for a bare raise with no
            # active exception is a real error event: recover_exception adds
            # the entry.
            if arg == 0 and raised.t != "none" {
                target = dispatch_exception(co, result, offset, offset, stack);
            } else {
                target = recover_exception(co, result, offset, stack);
            }
            if target >= 0 {
                ip = target;
                continue;
            }
            return result;
        }
        if op == OP_RERAISE {
            # CPython RERAISE: pop the exception (plus the saved lasti when
            # oparg != 0, restoring it as the attribution offset) and go
            # straight to exception_unwind -- a re-raise is not an error
            # event, so no traceback entry is added here. The exception table
            # is searched at the RERAISE's own offset, like CPython's
            # INSTR_OFFSET() in exception_unwind.
            raised = stack.pop();
            eff_offset = offset;
            if arg != 0 {
                saved_lasti = stack.pop();
                if isinstance(saved_lasti, PyInt) {
                    eff_offset = (saved_lasti as PyInt).val;
                }
            }
            result = py_raise_value(raised);
            target = dispatch_exception(co, result, offset, eff_offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return result;
        }
        if op == OP_COPY {
            stack.append(stack[len(stack) - arg]);
            continue;
        }
        if op == OP_SWAP {
            # SWAP(i) exchanges TOS with the item i positions down (stack[-i],
            # index len-i). TOS itself is position 1.
            swap_top = len(stack) - 1;
            swap_other = len(stack) - arg;
            swapped: PyObj = stack[swap_top];
            stack[swap_top] = stack[swap_other];
            stack[swap_other] = swapped;
            continue;
        }
        if op == OP_LOAD_SPECIAL {
            # LOAD_SPECIAL macro (_INSERT_NULL + _LOAD_SPECIAL): pop the context
            # manager, look up __enter__/__exit__, push [func, self_or_null] for
            # the CALL convention (method descriptors keep the owner as self).
            if len(stack) < 1 {
                return py_error("RuntimeError", "LOAD_SPECIAL stack underflow");
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
                    ip = target;
                    continue;
                }
                return method;
            }
            if isinstance(method, PyBoundMethod) {
                bm = method as PyBoundMethod;
                stack.append(bm.function);
                stack.append(bm.receiver);
            } else {
                stack.append(method);
                stack.append(owner);
            }
            continue;
        }
        if op == OP_WITH_EXCEPT_START {
            # WITH_EXCEPT_START: call the context manager's __exit__ with the
            # active exception info and push its truthy suppress flag.
            if len(stack) < 5 {
                return py_error("RuntimeError", "WITH_EXCEPT_START stack underflow");
            }
            val = stack[len(stack) - 1];
            exit_self = stack[len(stack) - 4];
            exit_func = stack[len(stack) - 5];
            exc_type: PyObj = py_none();
            if val.t == "exception" {
                exc_type = py_exception_type((val as PyException).type_name);
            }
            exit_args: list[PyObj] = [exc_type, val, py_none()];
            exit_result: PyObj = py_none();
            if exit_self.t != "none" {
                exit_result = bind_attribute(exit_func, exit_self).tp_call(
                    exit_args, {}
                );
            } else {
                exit_result = py_invoke(exit_func, exit_args, {});
            }
            if is_error(exit_result) {
                target = recover_exception(co, exit_result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return exit_result;
            }
            stack.append(exit_result);
            continue;
        }
        if op == OP_RETURN_GENERATOR {
            # The generator object already exists (created at call time). Push a
            # placeholder standing in for it; the following POP_TOP discards it.
            stack.append(py_none());
            continue;
        }
        if op == OP_YIELD_VALUE {
            # Suspend: pop the yielded value, freeze the resume point, and hand
            # the value up to gen_resume. run_frame re-enters here from ip.
            # oparg 1 marks a yield-from delegation, so a later throw knows to
            # route into the sub-iterator rather than inject at this point.
            value = stack.pop();
            frame.ip = ip;
            frame.yf = arg == 1;
            frame.exc_state = exc_handling;
            # Suspend deactivates this frame's handler entries in the global
            # exc_info view (re-appended on resume); without this, an unrelated
            # frame reading sys.exc_info() sees the suspended gen's exception.
            _handled_stack_remove_each(exc_handling);
            return PyYield(t="yield", val=value);
        }
        if op == OP_TO_BOOL {
            condition = stack.pop();
            truth = py_slot_truth(condition);
            if is_error(truth) {
                target = recover_exception(co, truth, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return truth;
            }
            stack.append(truth);
            continue;
        }
        if op == OP_CONTAINS_OP {
            container = stack.pop();
            member = stack.pop();
            contained = py_contains(container, member);
            if is_error(contained) {
                target = recover_exception(co, contained, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return contained;
            }
            truth = py_slot_truth(contained);
            if is_error(truth) {
                target = recover_exception(co, truth, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return truth;
            }
            present = (truth as PyBool).val;
            if arg == 1 {
                present = not present;
            }
            stack.append(PyBool(t="bool", val=present));
            continue;
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
            continue;
        }
        if op == OP_CALL_INTRINSIC_1 {
            operand = stack.pop();
            if arg == 6 {
                # INTRINSIC_LIST_TO_TUPLE: the tuple()-of-genexpr fast path
                # builds a list, then converts it in place.
                stack.append(PyTuple(t="tuple", items=(operand as PyList).items));
                continue;
            }
            if arg == 7 {
                # INTRINSIC_TYPEVAR (PEP 695 type parameter): operand is just
                # the parameter name string. Bounds/constraints never come
                # through here -- codegen wraps an unparameterized TypeVar via
                # CALL_INTRINSIC_2 TYPEVAR_WITH_BOUND/_WITH_CONSTRAINTS.
                if not isinstance(operand, PyStr) {
                    return py_error(
                        "SystemError", "CALL_INTRINSIC_1 TYPEVAR name must be a str"
                    );
                }
                stack.append(PyTypeVar(t="TypeVar", name=(operand as PyStr).val));
                continue;
            }
            if arg == 4 {
                # INTRINSIC_ASYNC_GEN_WRAP: CPython wraps each async-generator
                # yield in an AsyncGenWrappedValue so the anext/asend machinery
                # can tell yields from returns. The agen_* drivers unwrap it;
                # a wrapped value escaping any other path stays observable and
                # inert (same policy as CPython's opaque wrapper object).
                stack.append(PyAsyncGenWrappedValue(t="async_wrapped", val=operand));
                continue;
            }
            if arg == 11 {
                # INTRINSIC_TYPEALIAS (PEP 695 `type X = v`): operand is the
                # (name, type_params_or_None, lazy-value-fn) triple codegen
                # builds. Produce the lazily-evaluating alias object.
                if not isinstance(operand, PyTuple)
                    or len((operand as PyTuple).items) != 3 {
                    return py_error(
                        "SystemError", "malformed CALL_INTRINSIC_1 TYPEALIAS operand"
                    );
                }
                alias_items = (operand as PyTuple).items;
                if not isinstance(alias_items[0], PyStr) {
                    return py_error(
                        "SystemError", "CALL_INTRINSIC_1 TYPEALIAS name must be a str"
                    );
                }
                stack.append(PyTypeAlias(
                    t="TypeAliasType",
                    name=(alias_items[0] as PyStr).val,
                    type_params=alias_items[1],
                    value_fn=alias_items[2],
                ));
                continue;
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
                continue;
            }
            if arg == 5 {
                # INTRINSIC_UNARY_POSITIVE
                stack.append(operand);
                continue;
            }
            if arg == 2 {
                # INTRINSIC_IMPORT_STAR: `from module import *` binds the module's
                # exported names into the current globals. (Layer 3 only.)
                star_out = import_star_into(operand, globals);
                if is_error(star_out) {
                    target = recover_exception(co, star_out, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return star_out;
                }
                # CPython pushes None for the following POP_TOP.
                stack.append(py_none());
                continue;
            }
            if arg == 10 {
                # INTRINSIC_SUBSCRIPT_GENERIC (implicit PEP 695 class base):
                # operand is the type-parameter tuple; produce the
                # typing.Generic[T, ...] stand-in that py_build_class later
                # resolves through __mro_entries__ (update_build_class_bases).
                if not isinstance(operand, PyTuple) {
                    return py_error(
                        "SystemError",
                        "malformed CALL_INTRINSIC_1 SUBSCRIPT_GENERIC operand"
                    );
                }
                stack.append(PyGenericAlias(t="generic_alias", params=operand));
                continue;
            }
            return py_error("SystemError", "unsupported CALL_INTRINSIC_1 " + str(arg));
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
                    return rr_prep;
                }
                stack.append(rr_prep);
                continue;
            }
            if arg == 2 {
                # INTRINSIC_TYPEVAR_WITH_BOUND: (name, lazy-bound-evaluator).
                # The bound stays unevaluated until first __bound__ access --
                # see typevar_bound_value in py_attr.
                if not isinstance(lhs, PyStr) {
                    return py_error(
                        "SystemError", "malformed CALL_INTRINSIC_2 TYPEVAR_WITH_BOUND operand"
                    );
                }
                stack.append(PyTypeVar(
                    t="TypeVar", name=(lhs as PyStr).val, evaluate_bound=rhs
                ));
                continue;
            }
            if arg == 3 {
                # INTRINSIC_TYPEVAR_WITH_CONSTRAINTS: (name, lazy-constraints).
                if not isinstance(lhs, PyStr) {
                    return py_error(
                        "SystemError",
                        "malformed CALL_INTRINSIC_2 TYPEVAR_WITH_CONSTRAINTS operand"
                    );
                }
                stack.append(PyTypeVar(
                    t="TypeVar", name=(lhs as PyStr).val, evaluate_constraints=rhs
                ));
                continue;
            }
            if arg == 4 {
                # INTRINSIC_SET_FUNCTION_TYPE_PARAMS: (function, params-tuple);
                # CPython stores func_typeparams and returns the function.
                if not isinstance(lhs, PyFunction) or not isinstance(rhs, PyTuple) {
                    return py_error(
                        "SystemError",
                        "malformed CALL_INTRINSIC_2 SET_FUNCTION_TYPE_PARAMS operands"
                    );
                }
                fn_tps = lhs as PyFunction;
                fn_tps.attrs["__type_params__"] = rhs;
                stack.append(fn_tps);
                continue;
            }
            if arg == 5 {
                # INTRINSIC_SET_TYPEPARAM_DEFAULT: (typeparam,
                # lazy-default-evaluator); evaluated on first __default__
                # access -- see typevar_default_value in py_attr.
                if not isinstance(lhs, PyTypeVar) {
                    return py_error(
                        "SystemError", "malformed CALL_INTRINSIC_2 SET_TYPEPARAM_DEFAULT operand"
                    );
                }
                tp_default = lhs as PyTypeVar;
                tp_default.evaluate_default = rhs;
                stack.append(tp_default);
                continue;
            }
            return py_error("SystemError", "unsupported CALL_INTRINSIC_2 " + str(arg));
        }
        if op == OP_RETURN_VALUE {
            if len(stack) == 0 {
                return py_none();
            }
            return stack.pop();
        }
        if op == OP_POP_TOP {
            if len(stack) > 0 {
                stack.pop();
            }
            continue;
        }
        return py_error("SystemError", "unsupported opcode " + str(op));
    }
    return py_none();
}
