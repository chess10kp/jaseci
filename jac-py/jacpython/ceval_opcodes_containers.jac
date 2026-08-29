# ceval container opcode handlers (jac-py/PLAN.md §4 module-boundary constraint).
# BUILD_* / LIST_* / SET_* / MAP_* / DICT_* opcodes and container subscript
# paths from run_frame_inner. ceval.jac dispatches via thin forwarders.

import from objects {
    PyObj,
    PyList,
    PyDict,
    PySet,
    PySlice,
    PyStr,
    PyCode,
    is_error,
    py_none,
    py_error,
    expect_str,
}
import from ceval_defs { PyHostProxy, }
import from ceval_exceptions { recover_exception, }
import from ceval_api {
    to_host_coerce,
    iter_drain,
    append_to_list,
    dict_mapping_pairs,
    py_subscript,
    py_store_subscript,
    py_delete_subscript,
}

# Outcome tuple for frame dispatch: (-1, _) success; (>=0, _) jump ip; (-2, err) return.
def _recover_or_finish(
    co: PyCode, err: PyObj, offset: int, stack: list[PyObj]
) -> tuple[int, PyObj] {
    target = recover_exception(co, err, offset, stack);
    if target >= 0 {
        return (target, py_none());
    }
    return (-2, err);
}

def op_build_list(stack: list[PyObj], arg: int) -> tuple[int, PyObj] {
    values: list[PyObj] = [];
    while len(values) < arg {
        values.insert(0, stack.pop());
    }
    stack.append(PyList(t="list", items=values));
    return (-1, py_none());
}

def op_build_map(
    stack: list[PyObj], arg: int, co: PyCode, offset: int
) -> tuple[int, PyObj] {
    # key0,val0,key1,val1,... are pushed in source order; popping walks
    # them backwards, so buffer and replay forward to preserve insertion
    # order (dict iteration / .values() / .items() are order-sensitive).
    popped: list[PyObj] = [];
    j = 0;
    while j < arg * 2 {
        popped.insert(0, stack.pop());
        j = j + 1;
    }
    # Any hashable key lands in the native PyDict (hash-key protocol).
    # An unhashable key would raise TypeError in real Python; keep the
    # literal opaque on the host rather than raising during bootstrap.
    any_unhashable = False;
    j = 0;
    while j < arg {
        if is_error(popped[j * 2].tp_hashkey()) {
            any_unhashable = True;
        }
        j = j + 1;
    }
    if any_unhashable {
        # CPython raises TypeError naming the offending key's type.
        # Known-unhashable natives must RAISE here, not degrade: the
        # old opaque-host-map fallback let the host dict's raw
        # exception ESCAPE exec_code's PyError channel (TODO item 26).
        # Shapes that are merely not-yet-natively-hashed (e.g. slice,
        # hashable in CPython) keep the opaque-host fallback so their
        # behavior is unchanged.
        bm_err: PyObj = py_none();
        j = 0;
        while j < arg {
            keyobj = popped[j * 2];
            if keyobj.t == "list" or keyobj.t == "dict" or keyobj.t == "set" {
                bm_err = py_error(
                    "TypeError", "unhashable type: '" + keyobj.t + "'"
                );
                break;
            }
            j = j + 1;
        }
        if bm_err.t == "error" {
            # Route through frame unwinding so guest try/except handlers
            # can catch the display-literal raise (TODO item 26 residual:
            # a bare return bypassed handler dispatch).
            return _recover_or_finish(co, bm_err, offset, stack);
        }
        host_map: dict[any, any] = {};
        j = 0;
        while j < arg {
            hk_r = to_host_coerce(popped[j * 2]);
            hk = hk_r[1];
            if not ((hk_r[0] as bool)) {
                return (-2, hk_r[1] as PyObj);
            }
            hv2_r = to_host_coerce(popped[j * 2 + 1]);
            hv2 = hv2_r[1];
            if not ((hv2_r[0] as bool)) {
                return (-2, hv2_r[1] as PyObj);
            }
            host_map[hk] = hv2;
            j = j + 1;
        }
        stack.append(PyHostProxy(t="host", val=host_map));
        return (-1, py_none());
    }
    native_map = PyDict(t="dict", items={});
    j = 0;
    while j < arg {
        native_map.dict_set(popped[j * 2], popped[j * 2 + 1]);
        j = j + 1;
    }
    stack.append(native_map);
    return (-1, py_none());
}

def op_build_set(
    stack: list[PyObj], arg: int, co: PyCode, offset: int
) -> tuple[int, PyObj] {
    # Native PySet via the hash-key protocol; set algebra (|, &, -, ^) and
    # membership then run natively (PySet.nb_binop / set_contains).
    members: list[PyObj] = [];
    while len(members) < arg {
        members.insert(0, stack.pop());
    }
    native_set = PySet(t="set", items={}, frozen=False);
    set_err: PyObj = py_none();
    had_set_err = False;
    for member in members {
        set_err = native_set.set_add(member);
        if is_error(set_err) {
            had_set_err = True;
            break;
        }
    }
    if had_set_err {
        return _recover_or_finish(co, set_err, offset, stack);
    }
    stack.append(native_set);
    return (-1, py_none());
}

def op_set_update(
    stack: list[PyObj], arg: int, co: PyCode, offset: int
) -> tuple[int, PyObj] {
    # Same discipline as LIST_EXTEND above: drain through the guest
    # iterator machinery so non-iterables raise a CATCHABLE TypeError
    # ('int' object is not iterable) instead of escaping host-side and
    # killing the VM mid-set-display ({1, *1, 0, 4}).
    iterable = stack.pop();
    target_index = len(stack) - arg;
    target_set: PySet = stack[target_index] as PySet;
    set_drained = iter_drain(iterable);
    if is_error(set_drained) {
        return _recover_or_finish(co, set_drained, offset, stack);
    }
    for hostel in (set_drained as PyList).items {
        target_set.set_add(hostel);
    }
    return (-1, py_none());
}

def op_list_extend(
    stack: list[PyObj], arg: int, co: PyCode, offset: int
) -> tuple[int, PyObj] {
    # After popping the iterable, the target list sits at STACK[-arg]
    # (CPython extends STACK[-arg-1] pre-pop). The prior `-1-arg` form
    # only worked for a bare list literal, where a negative index still
    # landed on the list; with a callable+NULL below (e.g. len([...]))
    # it addressed the NULL instead.
    iterable = stack.pop();
    target_index = len(stack) - arg;
    ext_res = append_to_list(stack[target_index], iterable);
    if is_error(ext_res) {
        return _recover_or_finish(co, ext_res, offset, stack);
    }
    return (-1, py_none());
}

def op_list_append(stack: list[PyObj], arg: int) -> tuple[int, PyObj] {
    value = stack.pop();
    target_index = len(stack) - arg;
    (stack[target_index] as PyList).items.append(value);
    return (-1, py_none());
}

def op_set_add(stack: list[PyObj], arg: int) -> tuple[int, PyObj] {
    # set comprehension step: value=TOS, target set at STACK[-arg].
    set_member: PyObj = stack.pop();
    target_index = len(stack) - arg;
    (stack[target_index] as PySet).set_add(set_member);
    return (-1, py_none());
}

def op_map_add(stack: list[PyObj], arg: int) -> tuple[int, PyObj] {
    # dict comprehension step: value=TOS, key=TOS1, target dict at
    # STACK[-arg] after the two pops (mirrors LIST_APPEND's addressing).
    map_value: PyObj = stack.pop();
    map_key: PyObj = stack.pop();
    target_index = len(stack) - arg;
    (stack[target_index] as PyDict).dict_set(map_key, map_value);
    return (-1, py_none());
}

def op_dict_update(
    stack: list[PyObj], arg: int, co: PyCode, offset: int
) -> tuple[int, PyObj] {
    # {**a, **b}: merge source (TOS) into the dict at STACK[-arg-1];
    # duplicate keys are overwritten (last wins), no error.
    update_source: PyObj = stack.pop();
    target_index = len(stack) - arg;
    update_target = stack[target_index] as PyDict;
    update_view = dict_mapping_pairs(update_source, False);
    if is_error(update_view) {
        return _recover_or_finish(co, update_view, offset, stack);
    }
    update_pairs = update_view as PyDict;
    ukeys = update_pairs.dict_keys();
    uvals = update_pairs.dict_values();
    uj = 0;
    while uj < len(ukeys) {
        update_target.dict_set(ukeys[uj], uvals[uj]);
        uj = uj + 1;
    }
    return (-1, py_none());
}

def op_dict_merge(
    stack: list[PyObj], arg: int, co: PyCode, offset: int
) -> tuple[int, PyObj] {
    # f(**kw): merge source (TOS) into the kwargs dict at STACK[-arg-1].
    # Unlike DICT_UPDATE, a non-str key is a TypeError ("keywords must
    # be strings") and a duplicate key is a TypeError (a keyword passed
    # more than once). Both fire at FIRST offending key in iteration
    # order, matching _PyDict_MergeEx's ordered override=2 walk.
    merge_source: PyObj = stack.pop();
    # Stack effect (CPython): (callable, unused, unused, dict,
    # unused[oparg-1], update). After popping `update`, the target dict
    # sits `oparg` slots below the top.
    target_index = len(stack) - arg;
    merge_target = stack[target_index] as PyDict;
    merge_view = dict_mapping_pairs(merge_source, True);
    if is_error(merge_view) {
        return _recover_or_finish(co, merge_view, offset, stack);
    }
    merge_pairs = merge_view as PyDict;
    mkeys = merge_pairs.dict_keys();
    mvals = merge_pairs.dict_values();
    mj = 0;
    while mj < len(mkeys) {
        if not isinstance(mkeys[mj], PyStr) {
            merge_err = py_error("TypeError", "keywords must be strings");
            out = _recover_or_finish(co, merge_err, offset, stack);
            if out[0] >= 0 or out[0] == -2 {
                return out;
            }
            mj = len(mkeys);
            continue;
        }
        if merge_target.dict_contains(mkeys[mj]) {
            merge_err = py_error(
                "TypeError",
                "got multiple values for keyword argument '"
                    + expect_str(mkeys[mj]) + "'",
            );
            out = _recover_or_finish(co, merge_err, offset, stack);
            if out[0] >= 0 or out[0] == -2 {
                return out;
            }
            mj = len(mkeys);
            continue;
        }
        merge_target.dict_set(mkeys[mj], mvals[mj]);
        mj = mj + 1;
    }
    return (-1, py_none());
}

def op_binary_subscript(
    stack: list[PyObj], co: PyCode, offset: int
) -> tuple[int, PyObj] {
    rhs = stack.pop();
    lhs = stack.pop();
    result = py_subscript(lhs, rhs);
    if is_error(result) {
        return _recover_or_finish(co, result, offset, stack);
    }
    stack.append(result);
    return (-1, py_none());
}

def op_binary_slice(
    stack: list[PyObj], co: PyCode, offset: int
) -> tuple[int, PyObj] {
    # container[start:stop] -- step is always None for this opcode.
    stop = stack.pop();
    start = stack.pop();
    container = stack.pop();
    result = py_subscript(
        container, PySlice(t="slice", start=start, stop=stop, step=py_none())
    );
    if is_error(result) {
        return _recover_or_finish(co, result, offset, stack);
    }
    stack.append(result);
    return (-1, py_none());
}

def op_store_slice(
    stack: list[PyObj], co: PyCode, offset: int
) -> tuple[int, PyObj] {
    # container[start:stop] = value -- CPython _STORE_SLICE: the value
    # sits under (container, start, stop) on the stack and step is
    # always None (the stepped form lowers to BUILD_SLICE +
    # STORE_SUBSCR). Assignment runs through the same slot-based
    # protocol as STORE_SUBSCR with a slice key.
    slice_stop = stack.pop();
    slice_start = stack.pop();
    slice_container = stack.pop();
    slice_value = stack.pop();
    result = py_store_subscript(
        slice_container,
        PySlice(t="slice", start=slice_start, stop=slice_stop, step=py_none()),
        slice_value
    );
    if is_error(result) {
        return _recover_or_finish(co, result, offset, stack);
    }
    return (-1, py_none());
}

def op_store_subscr(
    stack: list[PyObj], co: PyCode, offset: int
) -> tuple[int, PyObj] {
    stored_index: PyObj = stack.pop();
    owner = stack.pop();
    stored_value: PyObj = stack.pop();
    result = py_store_subscript(owner, stored_index, stored_value);
    if is_error(result) {
        return _recover_or_finish(co, result, offset, stack);
    }
    return (-1, py_none());
}

def op_delete_subscr(
    stack: list[PyObj], co: PyCode, offset: int
) -> tuple[int, PyObj] {
    deleted_index: PyObj = stack.pop();
    owner = stack.pop();
    result = py_delete_subscript(owner, deleted_index);
    if is_error(result) {
        return _recover_or_finish(co, result, offset, stack);
    }
    return (-1, py_none());
}
