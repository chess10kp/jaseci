# Forwarding API for ceval spokes (jac-py/PLAN.md §4).
# Thin wrappers over vm_dispatch.ceval_ops so spokes never import ceval.

import from objects {
    PyObj,
    PyCallableIter,
    PyCell,
    PyCode,
    PyDict,
    PyDictIter,
    PyException,
    PySeqIter,
    PyTuple,
}
import from vm_dispatch { ceval_ops, }

def append_to_list(target: PyObj, iterable: PyObj) -> PyObj {
    return (ceval_ops["append_to_list"] as any)(target, iterable);
}

def as_error(value: PyObj) -> PyObj {
    return (ceval_ops["as_error"] as any)(value);
}

def bind_attribute(value: PyObj, receiver: PyObj) -> PyObj {
    return (ceval_ops["bind_attribute"] as any)(value, receiver);
}

def builtin_exec(
    args: list[PyObj],
    kwargs: dict[str, PyObj],
    frame_globals: dict[str, PyObj],
    frame_locals: dict[str, PyObj]
) -> PyObj {
    return (ceval_ops["builtin_exec"] as any)(args, kwargs, frame_globals, frame_locals);
}

def builtin_sorted_min_max(name: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    return (ceval_ops["builtin_sorted_min_max"] as any)(name, args, kwargs);
}

def call_user_dunder(u: PyObj, name: str, args: list[PyObj]) -> PyObj {
    return (ceval_ops["call_user_dunder"] as any)(u, name, args);
}

def calliter_next(it: PyCallableIter) -> PyObj {
    return (ceval_ops["calliter_next"] as any)(it);
}

def class_has_abc_meta(cls: PyObj) -> bool {
    return (ceval_ops["class_has_abc_meta"] as any)(cls);
}

def class_lookup_attr(cls: PyObj, name: str) -> PyObj {
    return (ceval_ops["class_lookup_attr"] as any)(cls, name);
}

def class_mro(cls: PyObj) -> list[PyObj] {
    return (ceval_ops["class_mro"] as any)(cls);
}

def descriptor_get(value: PyObj, instance: PyObj, owner: PyObj) -> PyObj {
    return (ceval_ops["descriptor_get"] as any)(value, instance, owner);
}

def dict_from_str_map(m: dict[str, PyObj]) -> PyDict {
    return (ceval_ops["dict_from_str_map"] as any)(m);
}

def dict_mapping_pairs(source: PyObj, kwargs_call: bool) -> PyObj {
    return (ceval_ops["dict_mapping_pairs"] as any)(source, kwargs_call);
}

def dictiter_error -> PyObj {
    return (ceval_ops["dictiter_error"] as any)();
}

def dictiter_yield(di: PyDictIter) -> PyObj {
    return (ceval_ops["dictiter_yield"] as any)(di);
}

def fast_value(co: PyCode, arg: int, fast: list[PyObj]) -> PyObj {
    return (ceval_ops["fast_value"] as any)(co, arg, fast);
}

def fast_value_check(
    co: PyCode,
    arg: int,
    fast: list[PyObj],
    assigned: list[bool],
) -> PyObj {
    return (ceval_ops["fast_value_check"] as any)(co, arg, fast, assigned);
}

def format_exc_unbound(co: PyCode, arg: int) -> PyObj {
    return (ceval_ops["format_exc_unbound"] as any)(co, arg);
}

def format_exception_text(exc: PyObj) -> PyObj {
    return (ceval_ops["format_exception_text"] as any)(exc);
}

def frame_clear(frame: PyObj) -> None {
    return (ceval_ops["frame_clear"] as any)(frame);
}

def from_host(raw: any) -> PyObj {
    return (ceval_ops["from_host"] as any)(raw);
}

def gen_close(gen: PyObj) -> PyObj {
    return (ceval_ops["gen_close"] as any)(gen);
}

def gen_resume(gen: PyObj, sent: PyObj) -> PyObj {
    return (ceval_ops["gen_resume"] as any)(gen, sent);
}

def gen_send(gen: PyObj, sent: PyObj) -> PyObj {
    return (ceval_ops["gen_send"] as any)(gen, sent);
}

def gen_throw(gen: PyObj, thrown: PyObj) -> PyObj {
    return (ceval_ops["gen_throw"] as any)(gen, thrown);
}

def host_builtin(name: str) -> PyObj {
    return (ceval_ops["host_builtin"] as any)(name);
}

def host_convert(value: PyObj, conv: int) -> PyObj {
    return (ceval_ops["host_convert"] as any)(value, conv);
}

def host_exception(exc: PyException) -> any {
    return (ceval_ops["host_exception"] as any)(exc);
}

def host_format(value: PyObj, spec: str) -> PyObj {
    return (ceval_ops["host_format"] as any)(value, spec);
}

def host_import(name: str, fromlist: PyObj) -> PyObj {
    return (ceval_ops["host_import"] as any)(name, fromlist);
}

def host_iter(value: PyObj) -> PyObj {
    return (ceval_ops["host_iter"] as any)(value);
}

def import_star_into(module: PyObj, globals: dict[str, PyObj]) -> PyObj {
    return (ceval_ops["import_star_into"] as any)(module, globals);
}

def iter_drain(src: PyObj) -> PyObj {
    return (ceval_ops["iter_drain"] as any)(src);
}

def layer3_is_active -> bool {
    return (ceval_ops["layer3_is_active"] as any)();
}

def load_name_fallback(name: str) -> PyObj {
    return (ceval_ops["load_name_fallback"] as any)(name);
}

def localsplus_name(co: PyCode, arg: int) -> str {
    return (ceval_ops["localsplus_name"] as any)(co, arg);
}

def make_function_from_stack(stack: list[PyObj], globals: dict[str, PyObj]) -> PyObj {
    return (ceval_ops["make_function_from_stack"] as any)(stack, globals);
}

def make_interpolation(value_i: PyObj, expr_s: str, conv: PyObj, fmt: PyObj) -> PyObj {
    return (ceval_ops["make_interpolation"] as any)(value_i, expr_s, conv, fmt);
}

def make_template(strings_t: PyTuple, parts_t: PyTuple) -> PyObj {
    return (ceval_ops["make_template"] as any)(strings_t, parts_t);
}

def members_of(arg: PyObj) -> PyObj {
    return (ceval_ops["members_of"] as any)(arg);
}

def normalize_throw_args(args: list[PyObj]) -> PyObj {
    return (ceval_ops["normalize_throw_args"] as any)(args);
}

def obj_is_callable(x: PyObj) -> bool {
    return (ceval_ops["obj_is_callable"] as any)(x);
}

def py_aiter(value: PyObj) -> PyObj {
    return (ceval_ops["py_aiter"] as any)(value);
}

def py_anext(aiter: PyObj) -> PyObj {
    return (ceval_ops["py_anext"] as any)(aiter);
}

def py_attr(value: PyObj, name: str) -> PyObj {
    return (ceval_ops["py_attr"] as any)(value, name);
}

def py_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    return (ceval_ops["py_binop"] as any)(kind, lhs, rhs);
}

def py_build_class(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    return (ceval_ops["py_build_class"] as any)(args, kwargs);
}

def py_compare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    return (ceval_ops["py_compare"] as any)(kind, lhs, rhs);
}

def py_contains(container: PyObj, member: PyObj) -> PyObj {
    return (ceval_ops["py_contains"] as any)(container, member);
}

def py_del_attr(value: PyObj, name: str) -> PyObj {
    return (ceval_ops["py_del_attr"] as any)(value, name);
}

def py_delete_subscript(container: PyObj, index: PyObj) -> PyObj {
    return (ceval_ops["py_delete_subscript"] as any)(container, index);
}

def py_dir(arg: PyObj) -> PyObj {
    return (ceval_ops["py_dir"] as any)(arg);
}

def py_dir_sorted(names: dict[str, bool]) -> PyObj {
    return (ceval_ops["py_dir_sorted"] as any)(names);
}

def py_get_awaitable(value: PyObj) -> PyObj {
    return (ceval_ops["py_get_awaitable"] as any)(value);
}

def py_hash(value: PyObj) -> PyObj {
    return (ceval_ops["py_hash"] as any)(value);
}

def py_id(o: PyObj) -> int {
    return (ceval_ops["py_id"] as any)(o);
}

def py_identity(a: PyObj, b: PyObj) -> bool {
    return (ceval_ops["py_identity"] as any)(a, b);
}

def py_import_name(
    name: str, fromlist: PyObj, level: int, globals: dict[str, PyObj]
) -> PyObj {
    return (ceval_ops["py_import_name"] as any)(name, fromlist, level, globals);
}

def py_invert(value: PyObj) -> PyObj {
    return (ceval_ops["py_invert"] as any)(value);
}

def py_invoke(fn: PyObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    return (ceval_ops["py_invoke"] as any)(fn, args, kwargs);
}

def py_isinstance(ob: PyObj, typ: PyObj) -> bool {
    return (ceval_ops["py_isinstance"] as any)(ob, typ);
}

def py_issubclass(cls: PyObj, typ: PyObj) -> bool {
    return (ceval_ops["py_issubclass"] as any)(cls, typ);
}

def py_iter(value: PyObj) -> PyObj {
    return (ceval_ops["py_iter"] as any)(value);
}

def py_len(value: PyObj) -> PyObj {
    return (ceval_ops["py_len"] as any)(value);
}

def py_match_class(
    subject: PyObj, type_obj: PyObj, nargs: int, kw_names: PyObj
) -> PyObj {
    return (ceval_ops["py_match_class"] as any)(subject, type_obj, nargs, kw_names);
}

def py_match_keys(map_obj: PyObj, keys: PyObj) -> PyObj {
    return (ceval_ops["py_match_keys"] as any)(map_obj, keys);
}

def py_negative(value: PyObj) -> PyObj {
    return (ceval_ops["py_negative"] as any)(value);
}

def py_raise_value(value: PyObj) -> PyObj {
    return (ceval_ops["py_raise_value"] as any)(value);
}

def py_repr(value: PyObj) -> PyObj {
    return (ceval_ops["py_repr"] as any)(value);
}

def py_set_attr(value: PyObj, name: str, field: PyObj) -> PyObj {
    return (ceval_ops["py_set_attr"] as any)(value, name, field);
}

def py_slot_truth(value: PyObj) -> PyObj {
    return (ceval_ops["py_slot_truth"] as any)(value);
}

def py_store_subscript(container: PyObj, index: PyObj, value: PyObj) -> PyObj {
    return (ceval_ops["py_store_subscript"] as any)(container, index, value);
}

def py_str(value: PyObj) -> PyObj {
    return (ceval_ops["py_str"] as any)(value);
}

def py_subscript(container: PyObj, index: PyObj) -> PyObj {
    return (ceval_ops["py_subscript"] as any)(container, index);
}

def py_type_has_mapping_flag(value: PyObj) -> bool {
    return (ceval_ops["py_type_has_mapping_flag"] as any)(value);
}

def py_type_has_sequence_flag(value: PyObj) -> bool {
    return (ceval_ops["py_type_has_sequence_flag"] as any)(value);
}

def py_type_of(o: PyObj) -> PyObj {
    return (ceval_ops["py_type_of"] as any)(o);
}

def resolve_cell(fast: list[PyObj], arg: int) -> PyCell | None {
    return (ceval_ops["resolve_cell"] as any)(fast, arg);
}

def send_into(receiver: PyObj, sent: PyObj) -> PyObj {
    return (ceval_ops["send_into"] as any)(receiver, sent);
}

def send_throw_into(receiver: PyObj, err: PyObj) -> PyObj {
    return (ceval_ops["send_throw_into"] as any)(receiver, err);
}

def seqiter_next(it: PySeqIter) -> PyObj {
    return (ceval_ops["seqiter_next"] as any)(it);
}

def stop_iteration(value: PyObj) -> PyObj {
    return (ceval_ops["stop_iteration"] as any)(value);
}

def super_lookup(defining_cls: PyObj, instance: PyObj, name: str) -> PyObj {
    return (ceval_ops["super_lookup"] as any)(defining_cls, instance, name);
}

def to_host(value: PyObj) -> any {
    return (ceval_ops["to_host"] as any)(value);
}

def to_host_coerce(value: PyObj) -> tuple[bool, any] {
    return (ceval_ops["to_host_coerce"] as any)(value);
}

def user_has_dunder(u: PyObj, name: str) -> bool {
    return (ceval_ops["user_has_dunder"] as any)(u, name);
}

def user_instance_dict(u: PyObj) -> PyObj {
    return (ceval_ops["user_instance_dict"] as any)(u);
}
